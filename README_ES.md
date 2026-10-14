# Zeta

**Un generador de sitios estáticos basado en Markdown. Dos asistentes nativos: Bash y PowerShell.**

Crea blogs, notas técnicas, portadas de videojuegos y catálogos de proyectos con **Pandoc** y archivos locales. No necesitas CMS, base de datos, Node.js ni frameworks JavaScript para generar o alojar el sitio.

| Linux / macOS | Windows |
| :-- | :-- |
| **Bash 4.3+** · `./zeta.sh` | **PowerShell 7+** · `.\zeta.ps1` |

**Los dos asistentes comparten artículos Markdown, configuración YAML, themes y estructura de HTML generado.** Puedes trabajar en Windows y continuar en Linux sin migrar los sitios. `main.sh` permanece como acceso compatible con scripts Bash antiguos.

[English](README.md)

## Inicio rápido

Clona el repositorio una vez:

~~~sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
~~~

### Linux / macOS (Bash)

Requiere Bash 4.3+ y [Pandoc](https://pandoc.org/installing.html) para generar HTML. Python 3 es opcional para la vista previa. macOS incluye una versión de Bash antigua; utiliza una más reciente.

~~~bash
make setup
./zeta.sh                  # Asistente interactivo
./zeta.sh create
./zeta.sh build mi-sitio
./zeta.sh preview mi-sitio
~~~

### Windows (PowerShell nativo)

Requiere PowerShell 7+. **No hace falta Bash ni WSL.** Puedes crear los sitios antes de instalar Pandoc; solo es necesario para generar HTML.

~~~powershell
.\zeta.ps1 deps            # Comprobar Pandoc
.\zeta.ps1 install-pandoc  # Instalación opcional con winget y confirmación
.\zeta.ps1                 # Asistente interactivo
.\zeta.ps1 create
.\zeta.ps1 build mi-sitio
.\zeta.ps1 preview mi-sitio -Port 8000
~~~

Si no tienes el administrador de paquetes de Windows, puedes instalar Pandoc desde [pandoc.org](https://pandoc.org/installing.html). Consulta la [guía de Windows](docs/powershell.md).

## Mismos comandos, ambos sistemas

Utiliza **el mismo comando** después de `./zeta.sh` desde Bash o `.\zeta.ps1` desde PowerShell:

| Comando | Función |
| :-- | :-- |
| `create` | Crear un sitio paso a paso |
| `sites` | Listar sitios y su estado |
| `edit SITIO` | Editar configuración y apariencia |
| `posts SITIO` / `new-post SITIO` | Listar / crear artículos Markdown |
| `theme SITIO TEMA ESTILO` | Cambiar tema y resaltado de código |
| `fonts SITIO` | Gestionar fuentes web locales |
| `build SITIO` / `build-all` | Generar un sitio / todos los sitios |
| `doctor SITIO` | Comprobar el estado para publicación |
| `preview SITIO` / `serve` | Previsualizar un sitio / servir el workspace |
| `dashboard` | Actualizar el índice de sitios |
| `clean SITIO` / `delete SITIO` | Limpiar archivos generados / eliminar un sitio |

Los dos asistentes muestran el logotipo ZETA a color, el estado de los sitios y menús numerados. La sintaxis del puerto depende de la shell: `./zeta.sh --port 8080 preview mi-sitio` frente a `.\zeta.ps1 preview mi-sitio -Port 8080`. Consulta `help` para ver todas las opciones.

## Páginas Markdown y blog opcional

El asistente pregunta si quieres incluir **Blog**, **About** y **Contacto**. Todo sitio nuevo incluye la portada Markdown `pages/index.md`; las demás páginas generan URLs limpias como `/about/` y navegación accesible. Si desactivas el blog, el resultado no contiene archivos ni URLs de publicaciones.

Puedes crear más páginas con `./zeta.sh new-page SITIO "Privacidad" privacidad` desde Bash o `.\zeta.ps1 new-page SITIO "Privacidad" privacidad` desde PowerShell; utiliza `pages SITIO` para listarlas. Los metadatos controlan el menú y los borradores. Consulta la [guía de páginas Markdown](docs/pages.md).

## Índice visual y contenido inicial compartidos

Bash y PowerShell generan **el mismo índice de sitios**, adaptable y navegable con teclado, en `sites/index.html`, con CSS compartido, estados de compilación, descripciones, temas, cantidad de artículos y acceso a las vistas previas.

Al crear un sitio, ambos generan **dos artículos Markdown completos**: uno con tablas, listas, notas a pie de página y otros formatos, y otro con varios lenguajes de programación para comprobar el resaltado. Los recursos comunes se mantienen en `templates/common/`. PowerShell compila `public/` automáticamente cuando Pandoc está instalado.

## Estructura de los sitios

~~~text
sites/mi-sitio/
├── config.yaml        # Metadatos y configuración de generación
├── posts/             # Artículos Markdown originales
├── landing.yaml       # Controles opcionales para la portada
├── landing.md         # Introducción opcional en Markdown
├── styles/            # Personalizaciones CSS
├── assets/            # Imágenes y fuentes opcionales
└── public/            # Archivos generados: despliega SOLO esto
    ├── index.html
    ├── posts.html
    ├── posts/
    ├── styles/
    ├── robots.txt
    └── sitemap.xml
~~~

Ejemplo de `config.yaml`:

~~~yaml
site:
  title: "Mi sitio"
  description: "Proyectos y notas técnicas"
  author: "Ada"
  language: "es"
  url: "https://example.com"

theme:
  name: "zen"
  pandoc_theme: "zenburn"

build:
  content_dir: "posts"
  output_dir: "public"
~~~

Los artículos son archivos `.md` con frontmatter YAML opcional: `title`, `date`, `description`, `slug`, `tags`, etc. Antes de publicar, configura `site.url` con la dirección pública: Zeta la utiliza para generar `sitemap.xml` y `robots.txt`.

## Ocho themes incluidos

| Theme | Uso recomendado |
| :-- | :-- |
| `zen` | Publicaciones oscuras y minimalistas |
| `paper` | Lectura y estilo editorial claro |
| `console` | Administración de sistemas y documentación técnica |
| `indie` | Portada de videojuego y devlog |
| `organization` | Organización open source y directorio de proyectos |
| `brutalist` | Diseño gráfico de alto contraste y creativo |
| `folio` | Portafolio editorial de tipografía serif |
| `aurora` | Producto tecnológico con gradientes oscuros |

Todos funcionan en Bash y PowerShell. `indie` y `organization` admiten imágenes de portada, botones y enlaces externos; consulta el [catálogo de temas](docs/theme-catalog.md) y [landings](docs/landing-themes.md). Hay fuentes locales opcionales: Cascadia Code, JetBrains Mono, Fira Code, IBM Plex Mono y Source Code Pro.

## SEO automático y diagnóstico de calidad

Bash y PowerShell normalizan automáticamente los metadatos SEO dentro de la compilación temporal: URLs canonical, descripciones, Open Graph y etiquetas para compartir enlaces. Puedes configurar `site.image` con un recurso local publicado en `assets/` o una URL HTTPS. Si falla la generación, se conserva el `public/` anterior.

Ejecuta `./zeta.sh doctor SITIO` o `.\\zeta.ps1 doctor SITIO` para revisar el Markdown, enlaces publicados, sitemap y SEO. Doctor muestra una puntuación orientativa de 0 a 100, incidencias por categoría y recomendaciones de corrección. No equivale a Lighthouse ni predice el posicionamiento.

Consulta la [guía SEO](docs/seo.md) y la [validación multiplataforma](docs/cross-platform-validation.md).

## Categorías, etiquetas y artículos relacionados

Los artículos Markdown admiten `category` y `tags` opcionales. Zeta genera automáticamente archivos estáticos en `/categories/` y `/tags/`, enlaza cada artículo con sus temas y recomienda hasta tres artículos relacionados. Los archivos se añaden al sitemap y reciben el SEO automático, sin JavaScript.

Los asistentes Bash y PowerShell preguntan por la categoría y las etiquetas. Consulta la [guía de gestión avanzada](docs/advanced-content.md).

## Generar y publicar

`build` convierte Markdown y temas en HTML estático dentro de `sites/<sitio>/public/`. **Publica únicamente `public/`**, nunca `posts/` ni `config.yaml`. El proceso utiliza un directorio temporal antes de sustituir el resultado anterior.

`preview` sirve localhost en el puerto 8000 por defecto: Bash utiliza Python 3 opcional y PowerShell el servidor .NET integrado. En PowerShell se detiene con **Ctrl+C** o **Q** en terminales compatibles.

Puedes desplegarlo en GitHub Pages, Cloudflare Pages, Netlify o cualquier servidor de archivos estáticos. Consulta [despliegue](docs/deployment.md).

## Guías y pruebas locales

- [Windows / PowerShell](docs/powershell.md) — instalación, Pandoc y vista previa.
- [Asistente de terminal](docs/terminal-assistant.md) — navegación en ambas plataformas.
- [Landings](docs/landing-themes.md) — portadas y tarjetas de proyectos.
- [Despliegue](docs/deployment.md) — alojamiento y URL pública.
- [Validación multiplataforma](docs/cross-platform-validation.md) — pruebas locales y limitaciones.

~~~bash
make syntax
bash tests/theme-smoke.sh
bash tests/workspace-parity-smoke.sh
bash tests/catalog-smoke.sh
~~~

~~~powershell
.\tests\powershell-create-smoke.ps1
.\tests\powershell-workspace-smoke.ps1
.\tests\powershell-build-smoke.ps1
.\tests\powershell-server-smoke.ps1
~~~

Comparten los archivos de autoría y los comandos; **no se garantiza que distintas versiones de Pandoc generen HTML idéntico byte a byte**. Las pruebas locales no requieren GitHub Actions.

**Licencia:** [MIT](LICENSE).
