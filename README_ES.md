# Zeta

Zeta convierte publicaciones Markdown en un blog estático listo para desplegar usando **Bash + Pandoc**.

El flujo de trabajo es deliberadamente pequeño:

1. Escribe Markdown en `sites/<sitio>/posts/`.
2. Genera el sitio.
3. Pruébalo localmente.
4. Despliega únicamente `sites/<sitio>/public/`.

No necesita base de datos, framework JavaScript, runtime Node.js, servidor CMS ni servidor de aplicaciones para generar o alojar el sitio.

**English:** [README.md](README.md)

## Requisitos

Obligatorios:

- Bash 4.3+
- Pandoc

Opcionales:

- Python 3 — servidor de preview local integrado
- Docker + Docker Compose — stack Nginx/HTTPS heredado y opcional
- ShellCheck — lint para desarrollo y contribuciones

Zeta no instala dependencias opcionales al abrir el asistente. En macOS instala un Bash actual con Homebrew, porque el Bash incluido por el sistema es anterior a la versión 4.3 requerida.

## Inicio rápido

```bash
git clone https://github.com/sempitern0/Zeta.git
cd Zeta
make setup
./main.sh
```

`make setup` comprueba el runtime, prepara `sites/`, valida la sintaxis Bash e instala el hook Git del repositorio cuando corresponde. No inicia Docker ni modifica `/etc/hosts`.

## Flujo de trabajo diario

### 1. Crear un sitio

```bash
./main.sh create
```

Se crea una estructura local como esta:

```text
sites/mi-blog/
├── config.yaml     # configuración local de generación
└── posts/          # fuentes Markdown locales
```

Después del primer build:

```text
sites/mi-blog/
├── config.yaml
├── posts/
└── public/         # despliega únicamente este directorio
    ├── index.html
    ├── posts.html
    ├── posts/
    ├── styles/
    ├── assets/        # sólo si el tema/sitio aporta assets
    ├── robots.txt
    ├── sitemap.xml
    └── sitemap.xsl
```

`config.yaml` y `posts/` son entradas de autoría/generación. Zeta no los copia a `public/`.

### 2. Añadir un post Markdown

La vía más rápida es el propio asistente:

```bash
./main.sh new-post mi-blog
```

También puedes crear manualmente un archivo dentro de `sites/mi-blog/posts/`:

```markdown
---
title: "Desplegando un sitio estático pequeño"
author: "Ada"
date: "2026-10-02"
description: "Una nota práctica de despliegue."
slug: "desplegando-un-sitio-estatico-pequeno"
tags: [linux, devops, web]
---

# Desplegando un sitio estático pequeño

Escribe el artículo en Markdown normal.
```

Se recomienda un nombre de archivo prefijado por fecha:

```text
2026-10-02-desplegando-un-sitio-estatico-pequeno.md
```

### 3. Listar posts locales

```bash
./main.sh posts mi-blog
```

El listado lee directamente los metadatos Markdown de `posts/`; no necesita generar el sitio antes.

Para el ciclo rápido de actualización después de copiar un Markdown nuevo:

```bash
cp articulo.md sites/mi-blog/posts/
./main.sh posts mi-blog
./main.sh update mi-blog
./main.sh preview mi-blog
```

### 4. Generar o actualizar el sitio estático

```bash
./main.sh build mi-blog
```

Cada build regenera `public/` desde Markdown y plantillas. Esto elimina páginas generadas obsoletas cuando un post se renombra o borra. Zeta genera primero en staging y sólo sustituye `public/` cuando Pandoc termina correctamente; si el build falla, el último artefacto válido permanece intacto.

Generar todos los sitios:

```bash
./main.sh build-all
```

### 5. Probar localmente

Preview de un único sitio:

```bash
./main.sh preview mi-blog
```

URL por defecto:

```text
http://127.0.0.1:8000/
```

Usar otro puerto:

```bash
./main.sh --port 8080 preview mi-blog
```

Generar todos los sitios y servir el dashboard local:

```bash
./main.sh serve
```

Después abre `http://127.0.0.1:8000/`. El dashboard enlaza al `public/` generado de cada sitio.

Python 3 sólo se utiliza para este servidor de preview. Si no está instalado, `build` sigue funcionando y puedes servir `public/` con cualquier servidor HTTP estático.

## Comandos de gestión

| Comando | Uso |
| --- | --- |
| `./main.sh` | Abrir el asistente interactivo |
| `./main.sh sites` | Listar sitios y estado de generación |
| `./main.sh create` | Crear un sitio |
| `./main.sh edit <sitio>` | Editar metadatos, URL de producción y tema |
| `./main.sh delete <sitio>` | Borrar un sitio local con confirmación explícita |
| `./main.sh clean <sitio>` | Borrar únicamente el `public/` generado |
| `./main.sh posts <sitio>` | Listar posts Markdown |
| `./main.sh new-post <sitio>` | Crear el esqueleto de un nuevo post |
| `./main.sh build <sitio>` / `update <sitio>` | Regenerar el `public/` de un sitio |
| `./main.sh build-all` | Regenerar todos los sitios |
| `./main.sh preview <sitio> [puerto]` | Generar y servir un sitio |
| `./main.sh serve [puerto]` | Generar todos y servir el dashboard local |
| `./main.sh dashboard` | Regenerar `sites/index.html` sin servidor |
| `./main.sh --force ...` | Omitir confirmaciones destructivas donde esté soportado |

## `config.yaml`

La configuración generada se mantiene pequeña:

```yaml
site:
  title: "Mi Blog"
  description: "Notas sobre sistemas y software"
  author: "Ada"
  language: "es"
  url: "https://example.com"

theme:
  name: "zen"
  pandoc_theme: "zenburn"

build:
  content_dir: "posts"
  output_dir: "public"
```

Antes de producción, cambia `site.url` por la URL pública real. Zeta la usa para crear las URLs absolutas de `sitemap.xml` y la referencia al sitemap dentro de `robots.txt`.

En un GitHub Pages de tipo proyecto, incluye la ruta del repositorio cuando forme parte de la URL pública, por ejemplo:

```yaml
url: "https://usuario.github.io/proyecto"
```

La navegación HTML utiliza enlaces relativos, por lo que el resultado puede moverse entre preview local, raíz de dominio y hosting bajo subrutas.

## Despliegue

El contrato de despliegue es siempre el mismo, independientemente del proveedor:

```text
sites/<sitio>/public/
```

Ese directorio es el artefacto estático completo. No subas `posts/` ni `config.yaml`. Zeta mantiene deliberadamente fuera del generador las credenciales y SDK de cada proveedor: genera localmente y publica el artefacto con el hosting que prefieras.

### Netlify — despliegue manual muy simple

1. Ejecuta `./main.sh build <sitio>`.
2. Abre Netlify Drop.
3. Arrastra `sites/<sitio>/public/` al área de despliegue.
4. Para actualizarlo, vuelve a generar localmente y arrastra el `public/` actualizado al área de despliegues del mismo sitio.

Guía oficial: https://docs.netlify.com/start/quickstarts/netlify-drop-quickstart/

### Vercel Drop — despliegue manual simple

1. Ejecuta `./main.sh build <sitio>`.
2. Abre Vercel Drop.
3. Arrastra la carpeta `public/`.
4. Vercel sirve los archivos estáticos directamente; no hace falta framework.

Vercel Drop: https://vercel.com/drop

### Cloudflare Pages

Para el modelo de fuentes locales de Zeta, **Direct Upload** es el encaje más limpio: genera el sitio y sube los assets estáticos ya preparados desde `public/`. Cloudflare no necesita ejecutar ningún framework.

Si más adelante creas un repositorio Git separado que contenga únicamente archivos desplegables, Pages también puede publicarlo configurando su directorio de salida estático.

Documentación oficial:

- https://developers.cloudflare.com/pages/get-started/direct-upload/
- https://developers.cloudflare.com/pages/configuration/build-configuration/

### GitHub Pages

GitHub Pages puede publicar desde una rama o mediante GitHub Actions.

El flujo de menor acoplamiento con Zeta consiste en mantener las fuentes de autoría localmente y copiar el contenido de `public/` a un repositorio Pages dedicado o a una rama de publicación. Configura Pages para servir esa rama desde la raíz del repositorio.

Si prefieres CI, usa un workflow de Pages que suba el artefacto estático. Un build CI desde Markdown debe instalar Pandoc antes de ejecutar Zeta.

Guía oficial: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

## HTML, CSS y compatibilidad

El tema `zen` mantiene una salida deliberadamente simple y sin JavaScript:

- HTML5 semántico;
- navegación con rutas relativas;
- foco de teclado visible;
- enlace para saltar directamente al contenido;
- soporte para `prefers-reduced-motion`;
- fuentes de sistema y monospace como fallback;
- layout responsive con CSS estándar;
- sin framework cliente ni hidratación.

El objetivo es que el resultado sea fácil de inspeccionar, cachear, archivar y servir desde prácticamente cualquier hosting estático.

## Docker/Nginx opcional

El stack existente Docker/Nginx sigue disponible para quien necesite reproducir HTTPS/proxy localmente. No es necesario para el ciclo normal de autoría; `preview` es la ruta recomendada cuando quieres servir únicamente el artefacto público:

```bash
make docker-up
make docker-ps
make docker-down
```

Ya no forma parte del setup por defecto ni del ciclo diario de autoría.

## Comprobaciones de desarrollo

Validación de sintaxis Bash sin dependencias adicionales:

```bash
make syntax
```

ShellCheck, si lo instalas explícitamente:

```bash
make lint
```

## Licencia

MIT. Consulta [LICENSE](LICENSE).


## Pruebas iniciales y fuentes opcionales

Cada sitio nuevo incluye dos posts Markdown de ejemplo. Entre ambos prueban encabezados, listas, tablas, enlaces, citas y bloques de código en Bash, Python, JavaScript, YAML, JSON, CSS y HTML.

Las fuentes web opcionales se instalan por sitio, no globalmente:

```bash
./main.sh fonts mi-blog
```

El build aplica siempre `templates/common` como base, después el tema seleccionado y finalmente las personalizaciones específicas del sitio.


## Temas, renderizado Markdown y resaltado de código

Zeta incluye ahora dos temas:

- `zen`: oscuro e inspirado en terminal.
- `paper`: claro, editorial y orientado a lectura.

Cambia la apariencia de un sitio y regenera automáticamente `public/`:

```bash
./main.sh theme mi-blog
```

También puedes hacerlo directamente:

```bash
./main.sh theme mi-blog paper zenburn
```

El renderizador usa el Markdown extendido de Pandoc para tablas pipe/grid, listas de
definición, task lists, notas al pie y bloques de código fenced. Las tablas se
envuelven para responsive mediante el runtime Lua incluido en Pandoc, sin añadir
ninguna dependencia externa.

El estilo de syntax highlighting seleccionado se incrusta en cada artículo, por lo
que `zenburn`, `haddock`, `pygments`, `tango`, `espresso`, `kate`, etc. controlan
realmente los colores de los tokens.

## Fuentes open source opcionales

Desde el asistente o con:

```bash
./main.sh fonts mi-blog
```

puedes seleccionar:

- Cascadia Code
- JetBrains Mono
- Fira Code
- IBM Plex Mono
- Source Code Pro

La fuente se descarga únicamente para ese sitio junto con su licencia upstream y
se publica en `public/` durante el build. El asistente regenera el sitio
automáticamente después del cambio.


### Cache local de fuentes

Las fuentes se descargan una sola vez por checkout en `.zeta-cache/fonts/`. El
directorio está ignorado por Git. Si un segundo sitio utiliza la misma fuente,
Zeta reutiliza el cache sin volver a acceder a la red y sólo copia la fuente
seleccionada al `assets/fonts/` local del sitio antes de generar `public/`.
