Customer QR menu is hosted as a static GitHub Pages site (web/menu) to avoid Render cold-start/loading screens.

QR URLs look like:
https://CLIENT-GITHUB-USERNAME.github.io/REPO-NAME?table=1

The static menu calls the production API at:
https://CHANGE-ME.onrender.com/api

The backend keeps /menu for backward compatibility. Set WEB_MENU_BASE_URL on Render to choose which host new QR codes use.
