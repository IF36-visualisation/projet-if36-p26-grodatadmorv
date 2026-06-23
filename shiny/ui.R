library(shiny)
library(shinydashboard)
library(plotly)

addResourcePath("img", "../img/")
addResourcePath("sprite", "../data/pokeapi/sprites")

title <- tags$a(href='#',
                tags$img(
                  src='img/grodatadmorv.png', 
                  height='50', 
                  width = '50'
                ),
                'Grodatadmorv'
)

dashboardPage(
  skin = "purple",
  dashboardHeader(title = title),
  dashboardSidebar(
    sidebarMenu(
      id = 'tabs',
      menuItem("Stats", tabName = "stats", icon = icon("dashboard")),
      menuItem("Rencontres", tabName = "rencontres", icon = icon("dashboard")),
      menuItem("Bestiaires", tabName = "bestiaires", icon = icon("dashboard"))
    ),
    # Sidebar
    conditionalPanel(
      condition = "input.tabs == 'stats'",
      selectInput(
        "stats_generation", "Région",
        choices = c("Kanto"=1,"Johto"=2,"Hoenn"=3,"Sinnoh"=4,
                    "Unova"=5,"Kalos"=6,"Alola"=7,"Galar"=8,
                    "Paldea"=9),
        selected = 1
      ),
    ),
    conditionalPanel(
      condition = "input.tabs == 'rencontres'",
      selectInput(
        "enc_region", "Région",
        choices = c("Kanto"=1,"Johto"=2,"Hoenn"=3,"Sinnoh"=4,
                    "Unova"=5,"Kalos"=6,"Alola"=7),
        selected = 1
      ),
      sliderInput("top_n", "Nombre de Pokémon", min=5, max=30, value=15),
      radioButtons(
        "enc_order", "Afficher les :",
         choices = c("Plus communs"="desc", "Plus rares"="asc"),
         selected = "desc"
      )
    ),
    conditionalPanel(
      condition = "input.tabs == 'bestiaires'",
      radioButtons("bio_measure", "Mesure",
                   choices = c("Poids" = "weight", "Taille" = "height"),
                   selected = "weight"),
    )
  ),
  dashboardBody(
    # Body
    tabItems(
      tabItem(
        tabName = "stats",
        fluidRow(
          valueBoxOutput("Total", width = 6),
          valueBoxOutput("Individus", width = 6),
        ),
        fluidRow(
          box(title = "Pokémon le plus lourd", width = 3, uiOutput("heaviest")),
          box(title = "Pokémon le plus léger", width = 3, uiOutput("lightest")),
          box(title = "Pokémon le plus grand", width = 3, uiOutput("tallest")),
          box(title = "Pokémon le plus petit", width = 3, uiOutput("smallest"))
        ),
        fluidRow(
          column(width = 8, offset = 2,
                 box(title = "Carte de la région", width = 12,
                     uiOutput("region_img"))
          )
        )
      ),
      tabItem(
        tabName = "rencontres",
        h2 = "Fréquence de rencontres par Pokémon",
        fluidRow(
          box(width = 12, status = "info", solidHeader = FALSE,
              tags$div(
                style = "color: #555;",
                tags$h4(icon("info-circle"), "A propos de ces données"),
                tags$ul(
                  tags$li(
                    "Les analyses de cette page portent sur une partie des Pokémon, ",
                    tags$b("selon la région sélectionné.")
                  ),
                  tags$li(
                    "Le graphique de gauche est ", 
                    tags$b("intéractif."), 
                    " Ce dernier peut être modifié via le slider 'Nombre de Pokémon' et peut être trié en fonction du plus 'Commun' ainsi que du plus 'Rare'."
                  ),
                  tags$li(
                    "Le graphique de droite n'est pas ", 
                    tags$b("intéractif."), 
                    " Ce dernier ne peut être modifié quand fonction de la région sélectionné."
                  )
                )
              )
          )
        ),
        fluidRow(
          box(title = "Fréquence de rencontres par Pokémon",
            plotlyOutput("plot_enc_bar"),
            uiOutput("plot_enc_bar_text"),
          ),
          box(title = "Distribution globale",
            plotlyOutput("plot_enc_treemap"),
            uiOutput("treemap_text"),
          )
        )
      ),
      tabItem(
        tabName = "bestiaires",
        h2 = "Conception du bestiaire",
        fluidRow(
          box(width = 12, status = "info", solidHeader = FALSE,
              tags$div(
                style = "color: #555;",
                tags$h4(icon("info-circle"), "A propos de ces données"),
                tags$ul(
                  tags$li(
                    "Les analyses de cette page portent sur l'ensemble des Pokémon, ",
                    tags$b("toutes régions confondues.")
                  ),
                  tags$li(
                    "L'habitat naturel n'est renseigné que pour les ", 
                    tags$b("générations 1 à 3 (386 espèces)"), 
                    ", cette donnée provenant des jeux Pokémon Rouge Feu / Vert Feuille. Les espèces plus récentes en sont dépourvues."
                  ),
                  tags$li(
                    "Seul le ", tags$b("type primaire"), 
                    " de chaque Pokémon est pris en compte ici ; les doubles types ne sont pas comptés deux fois."
                  ),
                  tags$li(
                    "Taille et poids sont convertis depuis les unités PokéAPI : ",
                    "décimètres → mètres, hectogrammes → kilogrammes."
                  ),
                  tags$li(
                    "Les formes spéciales (Méga-évolutions, Gigamax...) sont exclues des analyses biologiques."
                )
              )
            )
          )
        ),
        fluidRow(
          box(title = "Habitat par type",
              plotlyOutput("habitat_type"),
              uiOutput("habitat_type_txt"),
              
          ),
          box(title = "Evolution biologique par génération",
              plotlyOutput("bio_gen"),
              uiOutput("bio_gen_txt"),
              plotlyOutput("dimorphism_gen"),
              uiOutput("dimorphism_gen_txt")
          ),
        )
      )
    )
  )
)
