library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(plotly)
library(chorddiag)
library(htmlwidgets)

find_project_root <- function() {
  candidates <- c(
    normalizePath(getwd(), mustWork = TRUE),
    normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
  )

  root <- candidates[file.exists(file.path(candidates, "data", "pokeapi", "pokemon.csv"))][1]
  if (is.na(root)) {
    stop("Impossible de trouver la racine du projet depuis ", getwd(), call. = FALSE)
  }

  root
}

PROJECT_ROOT <- find_project_root()
data_path <- function(...) file.path(PROJECT_ROOT, ...)

addResourcePath("img", data_path("img"))

source_preparation <- function(project_root) {
  old_wd <- setwd(project_root)
  on.exit(setwd(old_wd), add = TRUE)

  source(file.path(project_root, "analyses", "00_preparation.R"), local = parent.frame())
}

source_preparation(PROJECT_ROOT)

q10_pokeapi <- pokeapi
q10_pokeapi_gen1 <- pokeapi_gen1
q10_type_names_en <- type_names_en %>% arrange(type_id)
q10_types_raw <- types_raw
q10_palette_types <- palette_types
q10_n_types <- 18

chord_gradient_js <- "
function(el, x) {
  var colors = x.options.groupColors || [];
  var svg = d3.select(el).select('svg');
  var defs = svg.select('defs.chord-gradients');

  function chordRadius(path) {
    var pathData = d3.select(path).attr('d') || '';
    var coords = pathData.match(/-?\\d*\\.?\\d+(?:e[-+]?\\d+)?/ig) || [0, 0];
    var x0 = Number(coords[0]);
    var y0 = Number(coords[1]);

    return Math.sqrt(x0 * x0 + y0 * y0);
  }

  function arcMidpoint(arc, radius) {
    var angle = (arc.startAngle + arc.endAngle) / 2 - Math.PI / 2;

    return {
      x: Math.cos(angle) * radius,
      y: Math.sin(angle) * radius
    };
  }

  if (defs.empty()) {
    defs = svg.append('defs').attr('class', 'chord-gradients');
  }

  defs.selectAll('linearGradient').remove();

  svg.selectAll('g.chords path')
    .each(function(d, i) {
      var radius = chordRadius(this);
      var sourcePoint = arcMidpoint(d.source, radius);
      var targetPoint = arcMidpoint(d.target, radius);
      var sourceColor = colors[d.source.index];
      var targetColor = colors[d.target.index];
      var gradientId = el.id + '-chord-gradient-' + i;
      var gradient = defs.append('linearGradient')
        .attr('id', gradientId)
        .attr('gradientUnits', 'userSpaceOnUse')
        .attr('x1', sourcePoint.x)
        .attr('y1', sourcePoint.y)
        .attr('x2', targetPoint.x)
        .attr('y2', targetPoint.y);

      gradient.append('stop')
        .attr('offset', '0%')
        .attr('stop-color', sourceColor);
      gradient.append('stop')
        .attr('offset', '45%')
        .attr('stop-color', sourceColor);
      gradient.append('stop')
        .attr('offset', '55%')
        .attr('stop-color', targetColor);
      gradient.append('stop')
        .attr('offset', '100%')
        .attr('stop-color', targetColor);

      d3.select(this)
        .style('fill', 'url(#' + gradientId + ')')
        .style('fill-opacity', 0.78)
        .style('stroke', 'rgba(255,255,255,0.72)')
        .style('stroke-width', '0.4px');
    });
}
"

encounters <- read.csv(data_path("data", "pokeapi", "encounters.csv"))
locations  <- read.csv(data_path("data", "pokeapi", "locations.csv"))

region_names <- c("1"="Kanto","2"="Johto","3"="Hoenn","4"="Sinnoh",
                  "5"="Unova","6"="Kalos","7"="Alola","8"="Galar")

pokemon <- read.csv(data_path("data", "pokeapi", "pokemon.csv")) %>%
  select(id, identifier) %>%
  rename(pokemon_name = identifier) %>%
  mutate(pokemon_name = stringr::str_to_title(pokemon_name))

merged_enc <- encounters %>%
  left_join(locations, by = c("location_area_id" = "id")) %>%
  left_join(pokemon, by = c("pokemon_id" = "id")) %>%
  filter(!is.na(region_id))

pokemon_full <- read.csv(data_path("data", "pokeapi", "pokemon.csv")) %>%
  select(id, identifier, weight, height) %>%
  rename(pokemon_name = identifier) %>%
  mutate(pokemon_name = stringr::str_to_title(pokemon_name))

habitat_names <- read.csv(data_path("data", "pokeapi", "pokemon_habitat_names.csv")) %>%
  filter(local_language_id == 9) %>%
  select(habitat_id = pokemon_habitat_id, habitat = name)

type_names_en <- read.csv(data_path("data", "pokeapi", "type_names.csv")) %>%
  filter(local_language_id == 9) %>%
  select(type_id, type = name)

ptypes <- read.csv(data_path("data", "pokeapi", "pokemon_types.csv")) %>%
  filter(slot == 1)   # type primaire

pspecies <- read.csv(data_path("data", "pokeapi", "pokemon_species.csv")) %>%
  select(id, habitat_id, generation_id, has_gender_differences, gender_rate)

habitat_type <- pspecies %>%
  left_join(ptypes, by = c("id" = "pokemon_id")) %>%
  left_join(habitat_names, by = "habitat_id") %>%
  left_join(type_names_en, by = "type_id") %>%
  filter(!is.na(habitat), !is.na(type))

bio_gen <- read.csv(data_path("data", "pokeapi", "pokemon.csv")) %>%
  select(id, identifier, height, weight) %>%
  left_join(pspecies, by = "id") %>%
  filter(id < 10000, !is.na(generation_id))

function(input, output) {
  # Ids des Pokémon présents dans la région sélectionnée
  ids_region <- reactive({
    merged_enc %>%
      filter(region_id == as.numeric(input$region_enc)) %>%
      distinct(pokemon_id) %>%
      pull(pokemon_id)
  })
  
  # Fabrique une carte (sprite + nom + poids) pour un Pokémon donné
  carte_pokemon_poids <- function(p) {
    tags$div(style = "text-align: center;",
             tags$img(src = paste0("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/", p$id, ".png"),
                      height = "120px", style = "image-rendering: pixelated;"),
             tags$h4(style = "color: white;", p$pokemon_name),
             tags$p(style = "color: #ccc;", paste0(p$weight / 10, " kg"))
    )
  }
  
  # Fabrique une carte (sprite + nom + taille) pour un Pokémon donné
  carte_pokemon_taille <- function(p) {
    tags$div(style = "text-align: center;",
             tags$img(src = paste0("https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/", p$id, ".png"),
                      height = "120px", style = "image-rendering: pixelated;"),
             tags$h4(style = "color: white;", p$pokemon_name),
             tags$p(style = "color: #ccc;", paste0(p$height / 10, " m"))
    )
  }

  type_matrix <- reactive({
    is_gen1 <- identical(input$generation, "gen1")
    dataset <- if (is_gen1) q10_pokeapi_gen1 else q10_pokeapi

    valid_type_ids <- if (is_gen1) {
      q10_types_raw %>%
        filter(type_generation <= 1) %>%
        pull(type_id)
    } else {
      seq_len(q10_n_types)
    }

    type_labels <- q10_type_names_en %>%
      filter(type_id %in% valid_type_ids) %>%
      arrange(type_id)

    type_positions <- setNames(seq_along(type_labels$type_id), type_labels$type_id)

    typed_pairs <- dataset %>%
      mutate(
        type2_id = if_else(type2_id %in% valid_type_ids, type2_id, NA_real_),
        type2_id = coalesce(type2_id, type1_id)
      ) %>%
      filter(type1_id %in% valid_type_ids, type2_id %in% valid_type_ids) %>%
      select(id, type1_id, type2_id)

    pair_counts <- typed_pairs %>%
      mutate(
        type_a_id = pmin(type1_id, type2_id),
        type_b_id = pmax(type1_id, type2_id)
      ) %>%
      count(type_a_id, type_b_id)

    mat <- matrix(0, nrow = nrow(type_labels), ncol = nrow(type_labels))
    for (k in seq_len(nrow(pair_counts))) {
      t1 <- type_positions[as.character(pair_counts$type_a_id[k])]
      t2 <- type_positions[as.character(pair_counts$type_b_id[k])]
      v  <- pair_counts$n[k]
      mat[t1, t2] <- v
      mat[t2, t1] <- v
    }

    rownames(mat) <- type_labels$type_name
    colnames(mat) <- type_labels$type_name
    attr(mat, "group_colors") <- unname(q10_palette_types[type_labels$type_name])

    mat
  })
  
  # --- Page 1 ---
  output$Individus <- renderValueBox({
    valueBox(length(ids_region()),
             "Pokémon distincts dans la région",
             icon = icon("list"), color = "purple")
  })
  
  output$Total <- renderValueBox({
    valueBox(n_distinct(merged_enc$pokemon_id),
             "Pokémon distincts au total",
             icon = icon("globe"), color = "purple")
  })
  
  output$heaviest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region(), id < 10000) %>%
      arrange(desc(weight)) %>% slice(1)
    carte_pokemon_poids(p)
  })
  
  output$lightest <- renderUI({
    p <- pokemon_full %>%
      filter(id %in% ids_region(), id < 10000, weight > 0) %>%
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
    region_label <- region_names[as.character(input$region_enc)]
    tags$div(style = "text-align: center;",
      tags$img(src = paste0("img/regions/", region_label, ".png"),
               height = "200px", width = "auto")
    )
  })
  
  # --- Page 2 ---
  output$plot_enc_bar <- renderPlotly({
    df <- merged_enc %>%
      filter(region_id == as.numeric(input$region_enc)) %>%
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
      filter(region_id == as.numeric(input$region_enc)) %>%
      group_by(pokemon_name) %>%
      summarise(nb = n(), .groups = "drop") %>%
      mutate(pct = round(nb / sum(nb) * 100, 1))
    
    top1    <- df %>% slice_max(nb, n = 1, with_ties = FALSE)
    last1   <- df %>% slice_min(nb, n = 1, with_ties = FALSE)
    top3_pct <- df %>% slice_max(nb, n = 3) %>% summarise(sum(pct)) %>% pull()
    nb_especes <- nrow(df)
    region_label <- region_names[as.character(input$region_enc)]
    
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
      filter(region_id == as.numeric(input$region_enc)) %>%
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
      filter(region_id == as.numeric(input$region_enc)) %>%
      group_by(pokemon_name) %>%
      summarise(nb = n(), .groups = "drop") %>%
      mutate(pct = nb / sum(nb) * 100)
    
    top1 <- df %>% slice_max(nb)
    top3_pct <- df %>% slice_max(nb, n = 3) %>% summarise(sum(pct)) %>% pull()
    region_label <- region_names[as.character(input$region_enc)]
    
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
    plus_mixte <- stats %>% arrange(part) %>% slice(1)
    
    tags$p(style = "color: #888; font-style: italic; padding: 10px;",
           paste0("Certains habitats sont fortement corrélés à un type — « ",
                  plus_type$habitat, " » est dominé par le type ", plus_type$top_type,
                  " (", round(plus_type$part), "% de ses espèces). À l'inverse, « ",
                  plus_mixte$habitat, " » est le plus diversifié avec ",
                  plus_mixte$nb_types, " types différents et aucun ne dépassant ",
                  round(plus_mixte$part), "%. La réponse à la question est donc nuancée : ",
                  "la corrélation type-habitat existe pour les milieux marqués (eau, forêt), ",
                  "mais les milieux génériques (prairie, urbain) accueillent une grande variété de types."))
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

  output$chordPlot <- renderChorddiag({
    mat <- type_matrix()
    group_colors <- attr(mat, "group_colors")

    htmlwidgets::onRender(chorddiag(
      mat,
      groupColors = group_colors,
      groupedgeColor = "#F8F9FA",
      chordedgeColor = "#F8F9FA",
      groupnamePadding = 35,
      showTicks = FALSE,
      fadeLevel = 0.04,
      tooltipGroupConnector = " ↔ ",
      tooltipUnit = " espèces"
    ), chord_gradient_js)
  })
}
