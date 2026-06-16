# ============================================================================
# 00_preparation.R — Chargement et préparation des données communes
# ============================================================================
# Ce script est sourcé une seule fois par le rapport maître (rapport_final.Rmd).
# Il construit les datasets partagés par toutes les questions d'analyse.
# ============================================================================

library(tidyverse)
library(arrow)
library(ggrepel)
library(scales)

# --- Chemins ---
POKEAPI_PATH <- "data/pokeapi/"
SMOGON_PATH  <- "data/smogon/"

# ============================================================================
# A) Données PokeAPI — Pokémon, stats, types, couleurs, formes
# ============================================================================

# --- Noms des stats (HP, Attack, Defense, Sp. Atk, Sp. Def, Speed) ---
stat_names <- read_csv(paste0(POKEAPI_PATH, "stat_names.csv"), show_col_types = FALSE) %>%
  filter(local_language_id == 9) %>%
  select(stat_id, stat_name = name)

# --- Stats en format wide (une colonne par stat) ---
pokemon_stats_wide <- read_csv(paste0(POKEAPI_PATH, "pokemon_stats.csv"), show_col_types = FALSE) %>%
  left_join(stat_names, by = "stat_id") %>%
  filter(stat_name %in% c("HP", "Attack", "Defense", "Special Attack", "Special Defense", "Speed")) %>%
  select(pokemon_id, stat_name, base_stat) %>%
  pivot_wider(names_from = stat_name, values_from = base_stat) %>%
  rename(Sp.Atk = `Special Attack`, Sp.Def = `Special Defense`) %>%
  mutate(BST = HP + Attack + Defense + Sp.Atk + Sp.Def + Speed)

# --- Table des espèces (generation, couleur, forme, capture_rate, etc.) ---
pokemon_species <- read_csv(paste0(POKEAPI_PATH, "pokemon_species.csv"), show_col_types = FALSE) %>%
  select(id, identifier, generation_id, evolves_from_species_id, evolution_chain_id,
         color_id, shape_id, habitat_id, capture_rate,
         is_baby, is_legendary, is_mythical)

# --- Table des Pokémon (taille, poids, base_experience) ---
pokemon_base <- read_csv(paste0(POKEAPI_PATH, "pokemon.csv"), show_col_types = FALSE) %>%
  filter(is_default == 1) %>%
  select(id, identifier, species_id, height, weight, base_experience)

# --- Types principaux et secondaires ---
pokemon_types_raw <- read_csv(paste0(POKEAPI_PATH, "pokemon_types.csv"), show_col_types = FALSE)

# Types passés (pour corriger les types qui ont changé entre générations)
pokemon_types_past <- read_csv(paste0(POKEAPI_PATH, "pokemon_types_past.csv"), show_col_types = FALSE)

# Table des noms de types (anglais)
type_names_en <- read_csv(paste0(POKEAPI_PATH, "type_names.csv"), show_col_types = FALSE) %>%
  filter(local_language_id == 9, type_id <= 18) %>%
  select(type_id, type_name = name)

# Types bruts (identifiant, génération d'introduction, classe de dégâts)
types_raw <- read_csv(paste0(POKEAPI_PATH, "types.csv"), show_col_types = FALSE) %>%
  filter(id <= 18) %>%
  select(type_id = id, type_identifier = identifier, type_generation = generation_id,
         damage_class_id)

# --- Couleurs (français) ---
color_names_fr <- read_csv(paste0(POKEAPI_PATH, "pokemon_color_names.csv"), show_col_types = FALSE) %>%
  filter(local_language_id == 5) %>%
  select(pokemon_color_id, color_fr = name)

# --- Formes physiques (anglais) ---
shape_names_en <- read_csv(paste0(POKEAPI_PATH, "pokemon_shape_prose.csv"), show_col_types = FALSE) %>%
  filter(local_language_id == 9) %>%
  select(pokemon_shape_id, shape_en = name)

# --- Efficacité des types ---
type_efficacy <- read_csv(paste0(POKEAPI_PATH, "type_efficacy.csv"), show_col_types = FALSE)

# ============================================================================
# B) Construction du dataset PokeAPI principal (toutes générations)
# ============================================================================

# Type principal (slot 1) — version actuelle
pokemon_type1 <- pokemon_types_raw %>%
  filter(slot == 1) %>%
  select(pokemon_id, type1_id = type_id)

# Type secondaire (slot 2)
pokemon_type2 <- pokemon_types_raw %>%
  filter(slot == 2) %>%
  select(pokemon_id, type2_id = type_id)

# Dataset PokeAPI complet : une ligne par espèce (forme par défaut)
pokeapi <- pokemon_species %>%
  left_join(pokemon_base, by = c("id" = "species_id")) %>%
  left_join(pokemon_stats_wide, by = c("id" = "pokemon_id")) %>%
  left_join(pokemon_type1, by = c("id" = "pokemon_id")) %>%
  left_join(pokemon_type2, by = c("id" = "pokemon_id")) %>%
  left_join(type_names_en, by = c("type1_id" = "type_id")) %>%
  rename(type1_name = type_name) %>%
  left_join(type_names_en, by = c("type2_id" = "type_id")) %>%
  rename(type2_name = type_name) %>%
  left_join(color_names_fr, by = c("color_id" = "pokemon_color_id")) %>%
  left_join(shape_names_en, by = c("shape_id" = "pokemon_shape_id")) %>%
  filter(!is.na(type1_name)) %>%
  # On renomme pour éviter les conflits (identifier vient de pokemon_base)
  rename(species_name = identifier.x, pokemon_name = identifier.y)

# ============================================================================
# C) Dataset Gen 1 filtré (pour Q18 et analyses Gen 1 spécifiques)
# ============================================================================

# Correction des types passés pour la Gen 1
past_types_gen1 <- pokemon_types_past %>%
  filter(slot == 1, generation_id >= 1) %>%
  group_by(pokemon_id) %>%
  slice_min(generation_id, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(pokemon_id, past_type_id = type_id)

# Pokémon Gen 1 avec types corrigés
pokeapi_gen1 <- pokeapi %>%
  filter(generation_id == 1) %>%
  left_join(past_types_gen1, by = c("id" = "pokemon_id")) %>%
  mutate(type1_id = coalesce(past_type_id, type1_id)) %>%
  # Mettre à jour le nom du type1 si changé
  select(-type1_name) %>%
  left_join(type_names_en, by = c("type1_id" = "type_id")) %>%
  rename(type1_name = type_name) %>%
  select(-past_type_id)

# ============================================================================
# D) Données Smogon (parquet) — agrégées sur toutes les dates
# ============================================================================

# --- Usage par mois ---
smogon_usage_monthly <- read_parquet(paste0(SMOGON_PATH, "gen1ou-smogon_usage.parquet"))
for (g in 1:9) {
  assign(
    paste0("smogon_usage_monthly_", g, "g"),
    read_parquet(paste0(SMOGON_PATH, "gen", g, "ou-smogon_usage.parquet"))
  )
}

# --- Usage agrégé (moyenne sur l'ensemble des mois) ---
smogon_usage <- smogon_usage_monthly %>%
  group_by(pokemon) %>%
  summarise(
    usage_pct_mean   = mean(usage_pct, na.rm = TRUE),
    raw_count_total  = sum(raw_count, na.rm = TRUE),
    n_months         = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(usage_pct_mean))

smogon_usage_by_gen <- map(1:9, ~ get(paste0("smogon_usage_monthly_", .x, "g")) %>%
  group_by(pokemon) %>%
  summarise(
    usage_pct_mean  = mean(usage_pct, na.rm = TRUE),
    raw_count_total = sum(raw_count, na.rm = TRUE),
    n_months        = n(),
    .groups = "drop"
    ) %>%
    arrange(desc(usage_pct_mean))
  ) %>%
  set_names(paste0("g", 1:9))

# --- Moves par mois ---
smogon_moves_monthly <- read_parquet(paste0(SMOGON_PATH, "gen1ou-smogon_moves.parquet"))

# --- Moves agrégés (usage moyen de chaque move par Pokémon) ---
smogon_moves <- smogon_moves_monthly %>%
  group_by(pokemon, move) %>%
  summarise(
    usage_pct_mean = mean(usage_pct, na.rm = TRUE),
    .groups = "drop"
  )

# --- Teammates par mois ---
smogon_teammates_monthly <- read_parquet(paste0(SMOGON_PATH, "gen1ou-smogon_teammates.parquet"))

# --- Teammates agrégés ---
smogon_teammates <- smogon_teammates_monthly %>%
  group_by(pokemon, teammate) %>%
  summarise(
    correlation_mean = mean(correlation, na.rm = TRUE),
    .groups = "drop"
  )

# --- Leads par mois ---
smogon_leads_monthly <- read_parquet(paste0(SMOGON_PATH, "gen1ou-smogon_leads.parquet"))

# --- Leads agrégés ---
smogon_leads <- smogon_leads_monthly %>%
  group_by(pokemon) %>%
  summarise(
    usage_pct_mean  = mean(usage_pct, na.rm = TRUE),
    raw_count_total = sum(raw_count, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(usage_pct_mean))

# --- Checks/Counters par mois ---
smogon_checks_monthly <- read_parquet(paste0(SMOGON_PATH, "gen1ou-smogon_checks.parquet"))

# --- Checks agrégés ---
smogon_checks <- smogon_checks_monthly %>%
  group_by(pokemon, check) %>%
  summarise(
    score_mean        = mean(score, na.rm = TRUE),
    pct_ko_mean       = mean(pct_ko, na.rm = TRUE),
    pct_switched_mean = mean(pct_switched, na.rm = TRUE),
    .groups = "drop"
  )

# ============================================================================
# E) Palettes et constantes graphiques partagées
# ============================================================================

# Palette de couleurs Pokémon (pour Q18)
palette_couleurs <- c(
  "Noir" = "#2d2d2d", "Bleu" = "#6495ED", "Brun" = "#8B4513",
  "Gris" = "#999999", "Vert" = "#32CD32", "Rose" = "#FF69B4",
  "Violet" = "#9370DB", "Rouge" = "#E8334A", "Blanc" = "#E0E0E0", "Jaune" = "#FFD700"
)

# Palette des 18 types Pokémon
palette_types <- c(
  "Normal"   = "#A8A77A", "Fighting" = "#C22E28", "Flying"   = "#A98FF3",
  "Poison"   = "#A33EA1", "Ground"   = "#E2BF65", "Rock"     = "#B6A136",
  "Bug"      = "#A6B91A", "Ghost"    = "#735797", "Steel"    = "#B7B7CE",
  "Fire"     = "#EE8130", "Water"    = "#6390F0", "Grass"    = "#7AC74C",
  "Electric" = "#F7D02C", "Psychic"  = "#F95587", "Ice"      = "#96D9D6",
  "Dragon"   = "#6F35FC", "Dark"     = "#705746", "Fairy"    = "#D685AD"
)

# Thème ggplot commun
theme_pokemon <- theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey45", size = 10),
    axis.text.x   = element_text(angle = 35, hjust = 1),
    panel.grid.minor = element_blank()
  )

cat("✓ Préparation des données terminée.\n")
cat("  → pokeapi :", nrow(pokeapi), "espèces (toutes gens)\n")
cat("  → pokeapi_gen1 :", nrow(pokeapi_gen1), "espèces (Gen 1)\n")
cat("  → smogon_usage :", nrow(smogon_usage), "Pokémon agrégés\n")
cat("  → smogon_usage_monthly :", nrow(smogon_usage_monthly), "lignes (",
    length(unique(smogon_usage_monthly$date)), "mois)\n")
