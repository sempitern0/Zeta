<h1 align="center">
  <img src="docs/assets/zeta-terminal-logo.svg" width="640" alt="Zeta — logotipo ASCII de la terminal">
</h1>

<p align="center"><strong>Escribe Markdown. Genera sitios estáticos. Publica donde quieras.</strong></p>
<p align="center">
  Generador de sitios estáticos desde la terminal, con asistentes nativos en Bash y PowerShell y renderizado mediante Pandoc.
  El resultado no necesita base de datos, CMS, Node.js ni servidor de aplicaciones.
</p>
<p align="center"><a href="README.md">English</a> · <strong>Español</strong></p>

---

## ¿Por qué Zeta?

Zeta convierte Markdown en un sitio web completo y publicable, manteniendo el contenido y la gestión del proyecto en la terminal.

- **Dos asistentes nativos:** Bash 4.3+ en Linux/macOS y PowerShell 7+ en Windows, con menús interactivos y comandos directos.
- **Markdown como fuente:** páginas, artículos y metadatos se conservan como archivos editables dentro de `sites/`.
- **Ocho temas con personalidad:** `zen`, `paper`, `console`, `indie`, `organization`, `brutalist`, `folio` y `aurora`, con diseños responsive.
- **Lectura cómoda:** índices generados por Pandoc, estilos propios de cada tema, barra lateral fija en escritorio y alternativa para móvil.
- **Publicación completa:** navegación, archivos de categorías y etiquetas, artículos relacionados, RSS/Atom, sitemaps, URLs canónicas y metadatos estructurados.
- **HTML estático y portable:** publica HTML, CSS y recursos locales en cualquier alojamiento estático compatible, sin CMS ni runtime de servidor.

El indicador opcional de la sección activa utiliza un pequeño script local; **Zeta no depende de frameworks JavaScript**. La edición y la generación se realizan en tu equipo.

## Inicio rápido

Clona el repositorio:

~~~sh
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
~~~

| Plataforma | Requisitos para generar HTML | Previsualización local |
| --- | --- | --- |
| Linux / macOS | Bash **4.3+** y [Pandoc](https://pandoc.org/installing.html) | Python 3 (opcional) |
| Windows | [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) y Pandoc | Servidor .NET integrado |

> Puedes crear y editar sitios antes de instalar Pandoc; Pandoc es necesario para generar HTML. El Bash incluido en macOS no cumple la versión mínima, así que instala uno más reciente. Windows no necesita Bash ni WSL.

### Bash · Linux / macOS

~~~bash
./zeta.sh deps
./zeta.sh create
# Elige "my-site" como identificador del sitio:
./zeta.sh build my-site
./zeta.sh doctor my-site
./zeta.sh preview my-site
~~~

### PowerShell · Windows

~~~powershell
.\zeta.ps1 deps
.\zeta.ps1 create
# Elige "my-site" como identificador del sitio:
.\zeta.ps1 build my-site
.\zeta.ps1 doctor my-site
.\zeta.ps1 preview my-site
~~~

En Windows, `.\zeta.ps1 install-pandoc` ofrece una instalación confirmada con `winget`; también puedes utilizar el [instalador oficial](https://pandoc.org/installing.html). Ejecuta cualquiera de las entradas **sin argumentos** para abrir su menú interactivo o usa `help` para ver los comandos.

La previsualización utiliza el puerto **8000** por defecto; detén el servidor con Ctrl+C. Los dos asistentes ofrecen flujos equivalentes, respetando la sintaxis propia de cada terminal.

## Estructura y edición de un sitio

Un sitio típico separa sus fuentes del resultado generado:

~~~text
sites/my-site/
├── config.yaml          # URL, título, idioma, tema y directorios
├── pages/
│   ├── index.md         # Portada Markdown
│   └── about.md         # Páginas opcionales
├── posts/               # Artículos Markdown (si activas el blog)
├── assets/              # Imágenes y fuentes locales opcionales
├── styles/              # Sobrescrituras CSS opcionales
└── public/              # Resultado generado: publica solo este directorio
~~~

El asistente de creación permite incluir blog, página About y Contact. Los artículos utilizan metadatos frontmatter:

~~~markdown
---
title: "Creando con Zeta"
description: "Mi primer artículo Markdown."
date: "2026-10-18"
category: "Proyectos"
tags: [markdown, sitios-estaticos]
---

## Introducción

Escribe en **Markdown** y vuelve a generar el sitio.

## Siguientes pasos

Añade secciones para construir automáticamente el índice del artículo.
~~~

Puedes usar el asistente para gestionar el contenido o editar directamente `pages/*.md`, `posts/*.md` y `config.yaml`. Consulta [Páginas](docs/pages.md) y [Contenido avanzado](docs/advanced-content.md) para navegación, borradores, categorías, etiquetas y artículos relacionados.

## Temas y personalización

| Tema | Identidad visual | Ideal para |
| --- | --- | --- |
| `zen` | Oscuro y minimalista | Blogs técnicos |
| `paper` | Tipografía editorial clara | Artículos extensos |
| `console` | Estética de terminal | DevOps e ingeniería |
| `indie` | Identidad de desarrollo de juegos | Videojuegos y devlogs |
| `organization` | Estructurado y limpio | Proyectos de código abierto |
| `brutalist` | Contrastes y formas contundentes | Porfolios experimentales |
| `folio` | Serif elegante y espacios amplios | Porfolios personales |
| `aurora` | Degradados oscuros y acentos luminosos | Productos digitales |

Cambia de tema sin reescribir el contenido Markdown:

~~~bash
./zeta.sh theme my-site aurora zenburn
./zeta.sh fonts my-site recommended  # Fuente de código abierto local y opcional
./zeta.sh dashboard                  # Galería de los ocho temas
~~~

En PowerShell utiliza `.\zeta.ps1`. Las fuentes son opcionales y se almacenan localmente. El tema elegido también afecta a las páginas Markdown y al índice lateral de los artículos. Consulta el [catálogo de temas](docs/theme-catalog.md) y la [guía de landings](docs/landing-themes.md) para diseños, configuración y CSS.

## Comandos compartidos

| Comando | Función |
| --- | --- |
| `create` / `sites` | Crear un sitio / listar los existentes |
| `edit SITE` | Editar metadatos y configuración |
| `pages SITE` / `new-page SITE TITLE SLUG` | Listar / crear páginas independientes |
| `posts SITE` / `new-post SITE` | Listar / crear artículos |
| `theme SITE THEME STYLE` | Seleccionar tema y resaltado de código de Pandoc |
| `fonts SITE [recommended]` | Gestionar fuentes opcionales locales |
| `build SITE` / `build-all` | Generar un sitio / todos los sitios |
| `doctor SITE` | Diagnosticar fuentes y resultado publicado |
| `preview SITE` | Generar y previsualizar localmente |
| `dashboard` / `serve` | Generar / servir el catálogo del espacio de trabajo |
| `clean SITE` / `delete SITE` | Limpiar salida generada / eliminar un sitio |

Para cambiar el puerto usa `./zeta.sh --port 8080 preview my-site` o `.\zeta.ps1 preview my-site -Port 8080`. `main.sh` sigue disponible como entrada Bash histórica.

## Generar, validar y publicar

1. Configura `site.url` en `sites/my-site/config.yaml` con tu URL pública real, incluido el subdirectorio del alojamiento si corresponde.
2. Ejecuta `build SITE` y después `doctor SITE`. Revisa las páginas y la navegación de los artículos en el navegador.
3. Publica **solo `sites/my-site/public/`** (o el directorio de salida configurado). Conserva Markdown y la configuración en tu espacio de trabajo.

Zeta genera primero en un directorio temporal; si falla, mantiene la salida publicada anterior. Doctor detecta enlaces locales rotos, recursos ausentes y problemas de metadatos, y muestra una puntuación **orientativa**, no un resultado de Lighthouse ni una predicción SEO. Consulta [Publicación](docs/deployment.md) y [SEO](docs/seo.md).

## Documentación y desarrollo

| Guía | Contenido |
| --- | --- |
| [Asistente de terminal](docs/terminal-assistant.md) | Menús y comportamiento de comandos |
| [Páginas Markdown](docs/pages.md) | Navegación, frontmatter, borradores y URLs |
| [Contenido avanzado](docs/advanced-content.md) | Categorías, etiquetas y artículos relacionados |
| [Catálogo de temas](docs/theme-catalog.md) | Los ocho temas, fuentes e índices |
| [Landings](docs/landing-themes.md) | Cabeceras, llamadas a la acción y tarjetas |
| [PowerShell](docs/powershell.md) | Instalación nativa en Windows y diagnóstico |
| [SEO](docs/seo.md) | URLs canónicas, metadatos, sitemaps y feeds |
| [Publicación](docs/deployment.md) | Alojamiento del sitio generado |
| [Validación](docs/cross-platform-validation.md) | Pruebas, paridad y limitaciones |

Comprobaciones locales útiles:

~~~bash
make syntax        # Sintaxis Bash
make test-tooling  # Regresiones de herramientas, sin Pandoc
make test          # Todas las pruebas Bash (requiere Pandoc)
make lint          # ShellCheck, si está instalado
~~~

PowerShell dispone de sus propias pruebas, documentadas en [Validación](docs/cross-platform-validation.md). Los dos asistentes comparten temas y Markdown, pero no se garantiza HTML idéntico byte a byte entre distintas plataformas o versiones de Pandoc.

Las contribuciones son bienvenidas: consulta [CONTRIBUTING.md](CONTRIBUTING.md). Proyecto distribuido bajo [licencia MIT](LICENSE).
