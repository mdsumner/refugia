# Pilot results site

Markdown sources for the GitHub Pages site (results, MVP brief, framework).
The workflow `.github/workflows/pages.yml` builds it with pandoc on every push
to `main` that touches `site/`. To build locally:

    bash site/build.sh _site

Figures in `figures/` come from `pilots/results_figures.R` and
`pilots/bridge_map.R`.
