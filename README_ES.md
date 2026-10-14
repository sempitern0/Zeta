# Zeta

Crea sitios estáticos desde Markdown con un asistente nativo en **Bash o PowerShell**.
Pandoc genera HTML; el hosting no necesita base de datos, CMS ni framework JavaScript.

[English](README.md) · **Español**

## Inicio rápido

```sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
```

| Plataforma | Requisitos | Entrada |
|---|---|---|
| Linux / macOS | Bash 4.3+, Pandoc; Python 3 para previsualizar | `./zeta.sh` |
| Windows | PowerShell 7+, Pandoc para generar HTML | `.\zeta.ps1` |

El Bash incluido en macOS es demasiado antiguo: usa Bash 4.3+. Windows no necesita
Bash ni WSL. Instala [Pandoc](https://pandoc.org/installing.html) para generar HTML;
puedes crear sitios antes de instalarlo. El comando `deps` comprueba dependencias.

```bash
./zeta.sh create            # Elige slug, tema y blog/About/Contact opcionales
# Este ejemplo supone que has elegido el slug my-site:
./zeta.sh build my-site
./zeta.sh preview my-site
```

```powershell
.\zeta.ps1 create
.\zeta.ps1 build my-site
.\zeta.ps1 preview my-site
```

La previsualización usa localhost y el puerto 8000. Detén el servidor con Ctrl+C.
Ejecuta la entrada sin argumentos para abrir el menú o con `help` para ver comandos.

## Escribir → generar → comprobar → publicar

| Edita | Contenido |
|---|---|
| `sites/my-site/pages/index.md` | Portada |
| `sites/my-site/pages/about.md` | Página About opcional |
| `sites/my-site/pages/*.md` | Otras páginas: contacto, privacidad… |
| `sites/my-site/posts/*.md` | Artículos, si activas el blog |
| `sites/my-site/config.yaml` | Título, descripción, URL pública, tema y directorios |
| `sites/my-site/assets/` | Imágenes y fuentes locales opcionales |

Ejemplo de página:

```markdown
---
title: "Nosotros"
description: "Qué hacemos y por qué."
nav: true
nav_order: 20
---
# Sobre nosotros

Creamos herramientas útiles. [Volver al inicio](index.md).
```

Configura `site.url` con la URL pública real, sustituye/elimina los artículos de ejemplo y ejecuta:

```bash
./zeta.sh build my-site
./zeta.sh doctor my-site
./zeta.sh preview my-site
```

En Windows usa los mismos comandos con `.\zeta.ps1`. **Publica únicamente
`sites/my-site/public/`** (o el directorio de salida configurado). Regenera tras
editar Markdown; el HTML generado no es la fuente que debes mantener. Si falla
la generación, se conserva la salida anterior. Consulta [publicación](docs/deployment.md).

## Mismos comandos, ambos sistemas

| Comando | Tarea |
|---|---|
| `create` / `sites` | Crear o listar sitios |
| `edit SITE` | Metadatos y apariencia |
| `pages SITE` / `new-page SITE "Privacidad" privacidad` | Listar o crear páginas |
| `posts SITE` / `new-post SITE` | Listar o crear artículos |
| `theme SITE THEME STYLE` / `fonts SITE` | Tema, resaltado y fuentes locales |
| `build SITE` / `build-all` | Generar uno/todos los sitios |
| `doctor SITE` | Diagnosticar fuentes, enlaces, metadatos y sitemap |
| `preview SITE` / `dashboard` | Previsualizar / actualizar el catálogo local |
| `clean SITE` / `delete SITE` | Borrar salida generada / eliminar todo un sitio |

Otro puerto: `./zeta.sh --port 8080 preview my-site` o
`.\zeta.ps1 preview my-site -Port 8080`. `main.sh` conserva la entrada Bash histórica.
La puntuación de Doctor es orientativa; no equivale a Lighthouse ni a posicionamiento SEO.

## Guías y mantenimiento

| Consulta | Guía |
|---|---|
| Páginas, navegación y borradores | [Markdown](docs/pages.md) |
| Categorías, etiquetas y artículos relacionados | [Contenido](docs/advanced-content.md) |
| Elegir entre ocho diseños | [Catálogo de temas](docs/theme-catalog.md) |
| Imágenes principales, CTA y tarjetas de proyectos | [Landings](docs/landing-themes.md) |
| URL canónica y metadatos sociales | [SEO](docs/seo.md) |
| Instalación y previsualización Windows | [PowerShell](docs/powershell.md) |
| Menús de terminal | [Asistente](docs/terminal-assistant.md) |
| Pruebas y diferencias entre plataformas | [Validación](docs/cross-platform-validation.md) |

```bash
make syntax        # Sintaxis Bash; no configura el sistema
make test-tooling  # Regresión de hook y lint; no necesita Pandoc
make test          # Todas las pruebas Bash; requiere Pandoc
make lint          # Requiere instalar ShellCheck explícitamente
```

`make setup` prepara opcionalmente el workspace e instala el hook pre-commit.
El hook revisa los archivos shell preparados para el commit sin reescribirlos.
Ambos motores comparten Markdown/YAML y temas; el HTML no se garantiza idéntico
entre plataformas/versiones de Pandoc. PowerShell dispone de [pruebas propias](docs/cross-platform-validation.md#check-powershell-locally).

[Licencia MIT](LICENSE).
