library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(plotly)

addResourcePath("img", "../img/")

sprite_dir <- "../data/pokeapi/sprites"

sprite_src <- function(id) {
  id <- as.character(id)
  sprite_file <- file.path(sprite_dir, paste0(id, ".png"))

  if (length(id) == 0 || is.na(id) || !file.exists(sprite_file)) {
    return("sprite/substitute.png")
  }

  paste0("sprite/", id, ".png")
}

encounters <- read.csv("../data/pokeapi/encounters.csv")
locations  <- read.csv("../data/pokeapi/locations.csv")
location_areas <- read.csv("../data/pokeapi/location_areas.csv")

generation_region_names <- c("1"="Kanto","2"="Johto","3"="Hoenn","4"="Sinnoh",
                             "5"="Unova","6"="Kalos","7"="Alola","8"="Galar",
                             "9"="Paldea")

encounter_region_names <- c("1"="Kanto","2"="Johto","3"="Hoenn","4"="Sinnoh",
                            "5"="Unova","6"="Kalos","7"="Alola")

encounter_region_ids <- as.numeric(names(encounter_region_names))

pokemon <- read.csv("../data/pokeapi/pokemon.csv") %>%
  select(id, identifier) %>%
  rename(pokemon_name = identifier) %>%
  mutate(pokemon_name = stringr::str_to_title(pokemon_name))

merged_enc <- encounters %>%
  filter(pokemon_id < 10000) %>%
  left_join(location_areas, by = c("location_area_id" = "id")) %>%
  left_join(locations, by = c("location_id" = "id")) %>%
  left_join(pokemon, by = c("pokemon_id" = "id")) %>%
  filter(region_id %in% encounter_region_ids)

pokemon_species <- read.csv("../data/pokeapi/pokemon_species.csv") %>%
  select(species_id = id, generation_id)

pokemon_full <- read.csv("../data/pokeapi/pokemon.csv") %>%
  filter(id < 10000, is_default == 1) %>%
  select(id, species_id, identifier, weight, height) %>%
  left_join(pokemon_species, by = "species_id") %>%
  rename(pokemon_name = identifier) %>%
  mutate(pokemon_name = stringr::str_to_title(pokemon_name))

habitat_names <- read.csv("../data/pokeapi/pokemon_habitat_names.csv") %>%
  filter(local_language_id == 9) %>%
  select(habitat_id = pokemon_habitat_id, habitat = name)

type_names_en <- read.csv("../data/pokeapi/type_names.csv") %>%
  filter(local_language_id == 9) %>%
  select(type_id, type = name)

ptypes <- read.csv("../data/pokeapi/pokemon_types.csv") %>%
  filter(slot == 1)   # type primaire

pspecies <- read.csv("../data/pokeapi/pokemon_species.csv") %>%
  select(id, habitat_id, generation_id, has_gender_differences, gender_rate)

habitat_type <- pspecies %>%
  left_join(ptypes, by = c("id" = "pokemon_id")) %>%
  left_join(habitat_names, by = "habitat_id") %>%
  left_join(type_names_en, by = "type_id") %>%
  filter(!is.na(habitat), !is.na(type))

bio_gen <- read.csv("../data/pokeapi/pokemon.csv") %>%
  select(id, identifier, height, weight) %>%
  left_join(pspecies, by = "id") %>%
  filter(id < 10000, !is.na(generation_id))

function(input, output) {
  # Ids des Pokémon présents dans la région sélectionnée
  ids_region <- reactive({
    pokemon_full %>%
      filter(generation_id == as.numeric(input$stats_generation)) %>%
      pull(id)
  })
  
  # Fabrique une carte (sprite + nom + poids) pour un Pokémon donné
  carte_pokemon_poids <- function(p) {
    tags$div(style = "text-align: center;",
             tags$img(src = sprite_src(p$id),
                      height = "120px", style = "image-rendering: pixelated;"),
             tags$h4(style = "color: white;", p$pokemon_name),
             tags$p(style = "color: #ccc;", paste0(p$weight / 10, " kg"))
    )
  }
  
  # Fabrique une carte (sprite + nom + taille) pour un Pokémon donné
  carte_pokemon_taille <- function(p) {
    tags$div(style = "text-align: center;",
             tags$img(src = sprite_src(p$id),
                      height = "120px", style = "image-rendering: pixelated;"),
             tags$h4(style = "color: white;", p$pokemon_name),
             tags$p(style = "color: #ccc;", paste0(p$weight / 100, " m"))
    )
  }
  
  # --- Page 1 ---
  output$Individus <- renderValueBox({
    valueBox(length(ids_region()),
             "Espèces principales dans la région",
             icon = icon("list"), color = "purple")
  })
  
  output$Total <- renderValueBox({
    valueBox(n_distinct(pokemon_full$id),
             "Espèces principales au total",
             icon = icon("globe"), color = "purple")
  })
  
  output$heaviest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region()) %>%
      arrange(desc(weight)) %>% slice(1)
    carte_pokemon_poids(p)
  })
  
  output$lightest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region(), weight > 0) %>%
      arrange(weight) %>% slice(1)
    carte_pokemon_poids(p)
  })
  
  output$tallest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region()) %>%
      arrange(desc(height)) %>% slice(1)
    carte_pokemon_taille(p)
  })
  
  output$smallest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region()) %>%
      arrange(height) %>% slice(1)
    carte_pokemon_taille(p)
  })
  
  output$region_img <- renderUI({
    region_label <- generation_region_names[as.character(input$stats_generation)]
    region_img <- paste0("img/regions/", region_label, ".png")
    region_file <- file.path("../img/regions", paste0(region_label, ".png"))

    if (!file.exists(region_file)) {
      return(tags$p(style = "text-align: center; color: #888;",
                    paste("Carte indisponible pour", region_label)))
    }

    tags$div(style = "text-align: center;",
      tags$img(src = region_img,
               height = "200px", width = "auto")
    )
  })
  
  # --- Page 2 ---
  output$plot_enc_bar <- renderPlotly({
    df <- merged_enc %>%
      filter(region_id == as.numeric(input$enc_region)) %>%
      group_by(pokemon_name) %>%
      summarise(nb_encounters = n(), .groups = "drop") %>%
      arrange(if (input$enc_order == "desc") desc(nb_encounters) else nb_encounters) %>%
      slice_head(n = input$top_n) %>%
      mutate(pokemon_name = factor(pokemon_name, levels = pokemon_name))
    
    p <- ggplot(df, aes(x = pokemon_name, y = nb_encounters)) +
      geom_col() +
      labs(x = "Pokémon", y = "Nombre de rencontres") +
      coord_flip()
    
    suppressWarnings(ggplotly(p))
  })
  output$plot_enc_bar_text <- renderUI({
    df <- merged_enc %>%
      filter(region_id == as.numeric(input$enc_region)) %>%
      group_by(pokemon_name) %>%
      summarise(nb = n(), .groups = "drop") %>%
      mutate(pct = round(nb / sum(nb) * 100, 1))
    
    top1    <- df %>% slice_max(nb, n = 1, with_ties = FALSE)
    last1   <- df %>% slice_min(nb, n = 1, with_ties = FALSE)
    top3_pct <- df %>% slice_max(nb, n = 3) %>% summarise(sum(pct)) %>% pull()
    nb_especes <- nrow(df)
    region_label <- encounter_region_names[as.character(input$enc_region)]
    
    tags$p(
      style = "color: #888; font-style: italic; padding: 10px;",
      paste0(
        "En ", region_label, ", ", nb_especes, " espèces différentes sont rencontrables. ",
        "Le Pokémon le plus fréquent est ", top1$pokemon_name,
        " avec ", top1$nb, " entrées de rencontre (", top1$pct, "% des rencontres). ",
        "À l'inverse, ", last1$pokemon_name, " est le plus rare avec seulement ",
        last1$nb, " entrée(s) (", last1$pct, "%). ",
        "Les 3 espèces les plus communes concentrent ", round(top3_pct), 
        "% de toutes les rencontres de la région."
      )
    )
  })
  
  output$plot_enc_treemap <- renderPlotly({
    df <- merged_enc %>%
      filter(region_id == as.numeric(input$enc_region)) %>%
      group_by(pokemon_id, pokemon_name) %>%
      summarise(nb_encounters = n(), .groups = "drop") %>%
      top_n(20, nb_encounters)
    
    plot_ly(type = "treemap",
            labels = df$pokemon_name,
            parents = rep("", nrow(df)),
            values = df$nb_encounters,
            textinfo = "label+percent root",
            hovertemplate = "<b>%{label}</b><br>Rencontres : %{value}<extra></extra>",
            marker = list(colorscale = "Purples")) %>%
      layout(title = "Top 20 (treemap)",
             paper_bgcolor = "rgba(0,0,0,0)",
             font = list(color = "white"))
  })
  output$treemap_text <- renderUI({
    df <- merged_enc %>%
      filter(region_id == as.numeric(input$enc_region)) %>%
      group_by(pokemon_name) %>%
      summarise(nb = n(), .groups = "drop") %>%
      mutate(pct = nb / sum(nb) * 100)
    
    top1 <- df %>% slice_max(nb)
    top3_pct <- df %>% slice_max(nb, n = 3) %>% summarise(sum(pct)) %>% pull()
    region_label <- encounter_region_names[as.character(input$enc_region)]
    
    tags$p(style = "color: #888; font-style: italic; padding: 10px;",
           paste0("En ", region_label, ", ", top1$pokemon_name,
                  " est le Pokémon le plus fréquemment rencontré (",
                  round(top1$pct), "% des rencontres). ",
                  "Les 3 espèces les plus communes concentrent à elles seules ",
                  round(top3_pct), "% de toutes les rencontres de la région, ",
                  "ce qui traduit une distribution très inégale typique des jeux Pokémon."))
  })
  
  # --- Page 3 ---
  output$habitat_type <- renderPlotly({
    df <- habitat_type %>%
      count(habitat, type)
    
    p <- ggplot(df, aes(x = type, y = habitat, fill = n)) +
      geom_tile(color = "white") +
      scale_fill_gradient(low = "#e0d4ec", high = "#7b2d8b") +
      labs(x = "Type primaire", y = "Habitat", fill = "Nb Pokémon") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
    
    suppressWarnings(ggplotly(p))
  })
  output$habitat_type_txt <- renderUI({
    stats <- habitat_type %>%
      count(habitat, type) %>%
      group_by(habitat) %>%
      summarise(top_type = type[which.max(n)],
                part = max(n) / sum(n) * 100,
                nb_types = n_distinct(type), .groups = "drop")
    
    plus_type  <- stats %>% arrange(desc(part)) %>% slice(1)
    plus_mixte <- stats %>% arrange(desc(nb_types)) %>% slice(1)
    
    tags$p(style = "color: #888; font-style: italic; padding: 10px;",
           paste0(
             "L'habitat ' ", plus_type$habitat, " ' montre la corrélation la plus forte : ",
             round(plus_type$part), "% de ses espèces sont de type ", plus_type$top_type,
             ", ce qui confirme une correspondance directe habitat/type. ",
             "À l'opposé, ' ", plus_mixte$habitat, " ' accueille ", plus_mixte$nb_types,
             " types différents avec aucun dépassant ", round(plus_mixte$part), "%, ",
             "ce qui montre que certains milieux sont au contraire très éclectiques. ",
             "La réponse est donc nuancée : la corrélation existe pour les milieux ",
             "physiquement marqués (eau, mer, montagne), mais disparaît pour les ",
             "environnements génériques comme la forêt ou les prairies."
           )
    )
  })
  
  output$bio_gen <- renderPlotly({
    mesure <- input$bio_measure   # "height" ou "weight"
    
    df <- bio_gen %>%
      mutate(valeur = if (mesure == "weight") weight / 10 else height / 10,
             generation = factor(generation_id))
    
    ylab <- if (mesure == "weight") "Poids (kg)" else "Taille (m)"
    
    p <- ggplot(df, aes(x = generation, y = valeur)) +
      geom_boxplot(fill = "#7b2d8b", alpha = 0.7) +
      labs(x = "Génération", y = ylab)
    
    suppressWarnings(ggplotly(p))
  })
  output$bio_gen_txt <- renderUI({
    mesure <- input$bio_measure
    df <- bio_gen %>%
      mutate(valeur = if (mesure == "weight") weight / 10 else height / 10) %>%
      group_by(generation_id) %>%
      summarise(moy = mean(valeur, na.rm = TRUE),
                med = median(valeur, na.rm = TRUE), .groups = "drop")
    
    premier <- df %>% slice_min(generation_id)
    dernier <- df %>% slice_max(generation_id)
    tendance <- if (dernier$moy > premier$moy) "augmenté" else "diminué"
    unite <- if (mesure == "weight") "kg" else "m"
    
    tags$p(style = "color: #888; font-style: italic; padding: 10px;",
           paste0("La moyenne a ", tendance, ", passant de ",
                  round(premier$moy, 1), " ", unite, " (gén. ", premier$generation_id,
                  ") à ", round(dernier$moy, 1), " ", unite, " (gén. ", dernier$generation_id,
                  "). La médiane (", round(dernier$med, 1), " ", unite,
                  " en dernière génération) reste bien inférieure à la moyenne, ",
                  "signe que quelques espèces très ", 
                  if (mesure == "weight") "lourdes" else "grandes",
                  " (légendaires notamment) tirent les valeurs vers le haut."))
  })
  
  output$dimorphism_gen <- renderPlotly({
    df <- bio_gen %>%
      group_by(generation_id) %>%
      summarise(pct_dimorphe = mean(has_gender_differences == 1) * 100,
                .groups = "drop")
    
    p <- ggplot(df, aes(x = factor(generation_id), y = pct_dimorphe)) +
      geom_col(fill = "#7b2d8b") +
      labs(x = "Génération", y = "% Pokémon à dimorphisme visible")
    
    suppressWarnings(ggplotly(p))
  })
  output$dimorphism_gen_txt <- renderUI({
    df <- bio_gen %>%
      group_by(generation_id) %>%
      summarise(pct = mean(has_gender_differences == 1) * 100, .groups = "drop")
    
    top <- df %>% slice_max(pct)
    moy_globale <- mean(df$pct)
    
    tags$p(style = "color: #888; font-style: italic; padding: 10px;",
           paste0("Le dimorphisme sexuel visible (apparence différente entre mâle et femelle) ",
                  "concerne en moyenne ", round(moy_globale), "% des espèces. ",
                  "Il culmine en génération ", top$generation_id, " (", round(top$pct), "%), ",
                  "qui correspond aux jeux Diamant/Perle où cette mécanique a été fortement développée. ",
                  "Ce critère ne capture que les différences d'apparence, pas les différences de ",
                  "répartition mâle/femelle au sein des espèces."))
  })
}
