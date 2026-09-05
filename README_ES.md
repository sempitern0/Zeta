🌐 **Leer en otros idiomas:** [English](README.md)

---

# bash-cli-starter

Una plantilla modular y lista para producción para construir aplicaciones y herramientas CLI en Bash robustas. Viene preconfigurada con linter ShellCheck, normalización multiplataforma CRLF-a-LF, tareas automatizadas mediante Makefile y hooks de Git pre-commit.

## 🌟 Características Principales

- **Arquitectura Modular**: Separación de responsabilidades integrada (punto de entrada `cli.sh`, módulos en `lib/`).
- **Comprobaciones Automáticas de Calidad**: Archivo `.shellcheckrc` preconfigurado y adaptado para proyectos Bash basados en librerías.
- **Compatibilidad Multiplataforma**: Conversión automática de saltos de línea (`CRLF` a `LF`) previniendo errores de ejecución en Windows/WSL (`SC1017`).
- **Hook de Git Pre-Commit**: Intercepta `git commit` para analizar automáticamente los scripts en Bash preparados en el _stage_.
- **Automatización con Makefile**: Configuración sencilla en un solo comando para permisos, instalación de hooks y análisis de código.
- **Soporte CI Multiplataforma**: Pipeline nativo de GitHub Actions activo por defecto, con configuraciones listas para usar en GitLab, Bitbucket, Azure y CircleCI.

## 📁 Estructura del Repositorio

```text
.
├── .github/
│   └── workflows/
│       └── lint.yml         # Pipeline CI activo para GitHub Actions
├── ci/                      # Plantillas preconfiguradas para otros proveedores de CI
│   ├── .gitlab-ci.yml.example
│   ├── azure-pipelines.yml.example
│   ├── bitbucket-pipelines.yml.example
│   └── circleci-config.yml.example
├── .gitattributes      # Fuerza saltos de línea LF en todos los entornos de SO
├── .shellcheckrc       # Reglas de ShellCheck adaptadas para scripts modulares
├── Makefile            # Ejecutor de tareas automatizadas
├── cli.sh              # Script principal y punto de entrada de la CLI
├── lib/
│   ├── cli.sh          # Procesamiento de argumentos y manejadores de opciones
│   └── common.sh       # Funciones auxiliares compartidas y utilidades del sistema
└── scripts/
    └── pre-commit      # Plantilla del hook pre-commit de Git
```

## 🚀 Primeros Pasos

### Requisitos previos

Asegúrate de tener instalados `git`, `make` y `shellcheck` en tu sistema.

- **macOS**: `brew install shellcheck`
- **Ubuntu/Debian**: `sudo apt-get install shellcheck`
- **Windows (PowerShell)**: `winget install koalaman.shellcheck`

### Configuración en un solo comando

Ejecuta el comando de preparación para otorgar permisos de ejecución, instalar el hook pre-commit de Git y verificar el código:

```bash
make setup
```

## 🛠️ Uso y Comandos del Makefile

| Comando                   | Descripción                                                                        |
| :------------------------ | :--------------------------------------------------------------------------------- |
| `make setup`              | Configuración inicial completa: otorga permisos, instala hooks y ejecuta el linter |
| `make lint`               | Corrige saltos de línea y ejecuta ShellCheck en todos los archivos `.sh`           |
| `make install-hooks`      | Copia el script de pre-commit a `.git/hooks/pre-commit`                            |
| `make chmod`              | Otorga permisos de ejecución (`+x`) a scripts y hooks                              |
| `make install-shellcheck` | Intenta autoinstalar ShellCheck usando el gestor de paquetes del sistema           |

## 🧪 Hook de Pre-commit

Una vez instalado, el hook de pre-commit se ejecuta automáticamente cada vez que realizas un `git commit`. Convierte los saltos de línea a `LF` y verifica todos los archivos `.sh` en _stage_ con ShellCheck. Si se detecta algún error de sintaxis o estilo, el commit se bloquea hasta que sea resuelto.

## 🔄 Integración Continua (CI/CD)

La integración continua está preconfigurada directamente en el directorio raíz (y `.circleci/`), lista para ejecutar `make lint` en las principales plataformas. No requiere mover archivos ni configuraciones adicionales; simplemente sube tu repositorio a tu proveedor de preferencia:

| Proveedor                  | Archivo de Configuración     | Estado             |
| :------------------------- | :--------------------------- | :----------------- |
| **🐙 GitHub Actions**      | `.github/workflows/lint.yml` | ✅ Listo para usar |
| **🦊 GitLab CI**           | `.gitlab-ci.yml`             | ✅ Listo para usar |
| **🪣 Bitbucket Pipelines** | `bitbucket-pipelines.yml`    | ✅ Listo para usar |
| **☁️ Azure Pipelines**     | `azure-pipelines.yml`        | ✅ Listo para usar |
| **⭕ CircleCI**            | `.circleci/config.yml`       | ✅ Listo para usar |

---

# Cómo Extender los Argumentos del CLI (`parse_args` y `show_help`)

Esta guía explica cómo añadir nuevas _flags_, opciones con valores y opciones largas al analizador de argumentos en `lib/cli.sh`.

---

## 1. Visión general de `getopts`

El analizador de argumentos utiliza la herramienta integrada `getopts` de Bash combinada con lógica personalizada para manejar argumentos cortos (`-o`) y largos (`--option`).

La cadena pasada a `getopts` controla los requisitos de cada opción:

```bash
while getopts "o:c:fvh-:" opt; do
```

- `v`: Una letra **sin** dos puntos es un _flag_ booleano (no requiere valor).
- `o:`: Una letra **con** dos puntos requiere un valor (ej. `-o <archivo>`).
- `-:`: El `-:` al final intercepta opciones largas que comienzan con `--`.

---

## 2. Paso a Paso: Añadir una Nueva Opción Corta y Larga

Supongamos que deseas añadir una opción `--target` / `-t` que acepte un texto, y un _flag_ booleano `--dry-run`.

### Paso 1: Declarar Variables por Defecto

Define los valores por defecto al inicio de `lib/cli.sh` (o a nivel de script):

```bash
TARGET_ENV="production"
DRY_RUN=false
```

### Paso 2: Actualizar la Cadena de `getopts`

Añade `t:` (requiere valor) a la cadena de opciones:

```bash
# Antes: "o:c:fvh-:"
# Después: "o:c:t:fvh-:"
while getopts "o:c:t:fvh-:" opt; do
```

### Paso 3: Manejar la Opción Corta (`case "$opt"`)

Añade el controlador de la letra en el `case` principal:

```bash
case "$opt" in
    t) TARGET_ENV="$OPTARG" ;;
    # ...
esac
```

### Paso 4: Manejar Opciones Largas (`case "${OPTARG}"`)

Añade los casos para la sintaxis de opciones largas en la sección `-)`:

```bash
-)
    case "${OPTARG}" in
        # Flag booleano largo
        dry-run) DRY_RUN=true ;;

        # Opción larga con sintaxis '=' (--target=staging)
        target=*) TARGET_ENV="${OPTARG#*=}" ;;

        # Opción larga con espacio (--target staging)
        target)
            TARGET_ENV="${!OPTIND}"
            OPTIND=$((OPTIND + 1))
            ;;

        # ...
    esac
    ;;
```

### Paso 5: Actualizar `show_help`

Actualiza el mensaje de ayuda en `lib/cli.sh` para documentar los nuevos parámetros:

```bash
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPCIONES]

Opciones:
  -o, --output <archivo>  Especifica la ruta del archivo de salida
  -c, --config <archivo>  Ruta al archivo de configuración
  -t, --target <env>      Establece el entorno de destino (por defecto: production)
  -f, --force             Fuerza la ejecución sin confirmación
      --dry-run           Simula la ejecución sin modificar el sistema
  -v, --verbose           Habilita la salida detallada en los logs
  -h, --help              Muestra este mensaje de ayuda y sale
EOF
}
```

---

## 3. Lista de Comprobación Rápida

Al añadir un nuevo argumento:

1. [ ] Declarar una variable global por defecto.
2. [ ] Actualizar la cadena de `getopts` (añadir `:` si acepta un valor).
3. [ ] Añadir el controlador de opción corta (`t)`).
4. [ ] Añadir los controladores de opción larga (`target=*` y `target)`).
5. [ ] Actualizar el texto de salida en `show_help()`.
6. [ ] Probar la sintaxis corta y larga (`-t dev`, `--target=dev`, `--target dev`).

---

# Referencia de Utilidades de `lib/common.sh`

El módulo `lib/common.sh` proporciona utilidades estándar para salida en interfaz, detección del sistema, manipulación de archivos e interacción con el usuario.

---

## 1. Logs y Formato

Todas las funciones de mensajes formatean el texto con colores ANSI y envían la salida directamente a `STDERR` (`>&2`) para evitar corromper los flujos de datos en `STDOUT`.

### Registros Estándar

```bash
msg_info "Cargando configuración..."     # [INFO] Cian
msg_success "Base de datos conectada."   # [OK] Verde
msg_warn "Poco espacio en disco."        # [WARN] Amarillo
msg_error "Error al escribir archivo."   # [ERROR] Rojo
```

### Registros de Procesos

```bash
msg_search "Buscando paquetes..."        # [SEARCH] Púrpura
msg_exec "Ejecutando migración..."       # [EXEC] Azul
msg_download "Descargando archivo..."    # [FETCH] Azul Negrita
msg_build "Compilando binario..."        # [BUILD] Cian Negrita
msg_skip "El archivo existe, omitiendo..." # [SKIP] Gris
msg_debug "Nivel de OPTIND: $OPTIND"     # [DEBUG] Gris
```

### Separadores Visuales

```bash
print_section "Fase de Compilación" # Muestra "===> Fase de Compilación" en blanco negrita
print_separator                    # Imprime una línea gris de 50 caracteres
```

---

## 2. Detección de SO y Sistema

### Gestor de Paquetes y Distribución

- **`detect_package_manager`**: Imprime `apt` o `pacman` en `STDOUT`. Devuelve código `1` si no encuentra ninguno.
- **`detect_distribution`**: Analiza `/etc/os-release` o `uname` para identificar la familia del SO (`debian`, `arch`, `fedora` o `macos`).

```bash
distro=$(detect_distribution)
case "$distro" in
    debian) apt-get update ;;
    arch) pacman -Sy ;;
esac
```

### Comprobaciones del Entorno

- **`is_server_environment`**: Devuelve `0` (verdadero) si es un entorno sin interfaz gráfica (_headless_/servidor), o `1` (falso) si detecta una sesión gráfica (Xorg/Wayland/GDM/SDDM).
- **`is_wsl`**: Devuelve `0` si se ejecuta dentro del Subsistema de Windows para Linux (WSL).

```bash
if is_wsl; then
    msg_info "Ejecutándose en entorno WSL."
fi
```

---

## 3. Operaciones de Sistema y Archivos

### Permisos y Root

- **`check_root`**: Obliga la ejecución como root. Detiene el script con código `1` si `$EUID` no es cero.
- **`ensure_sudo_installed`**: Verifica si `sudo` está instalado; intenta instalarlo automáticamente mediante el gestor de paquetes si se ejecuta como root.

### Manipulación de Archivos

- **`copy_with_backup <origen> <destino> <usuario>`**: Copia un archivo de forma segura. Si el `<destino>` existe, crea un respaldo `<destino>.bak` antes de sobrescribir. Preserva el respaldo original si el archivo `.bak` ya existe.

```bash
copy_with_backup "configs/app.conf" "/etc/app.conf" "$SUDO_USER"
```

### Utilidades Varias

- **`command_exists <comando>`**: Devuelve `0` si el comando está presente en `$PATH`, de lo contrario `1`.
- **`slugify <cadena>`**: Convierte el texto de entrada en un _slug_ en minúsculas y seguro para URLs.

```bash
clean_name=$(slugify "¡Mi Proyecto De Prueba 123!") # Salida: "mi-proyecto-de-prueba-123"
```

---

## 4. Interfaz de Usuario e Interacción

### Confirmaciones de Usuario

- **`prompt_confirmation <mensaje> [opcion_por_defecto]`**: Solicita confirmación `[y/N]` al usuario. Devuelve `0` para Sí, `1` para No/Cancelado.

```bash
if prompt_confirmation "¿Sobrescribir la configuración existente?" "N"; then
    # Proceder con la escritura
fi
```

### Barra de Progreso

- **`show_progress_bar <actual> <total> [ancho]`**: Muestra una barra de progreso ASCII dinámica e interactiva en `STDOUT`.

```bash
total=50
for ((i=1; i<=total; i++)); do
    show_progress_bar "$i" "$total" 30
    sleep 0.05
done
```

---

## 🤝 Contribución

¡Las contribuciones son bienvenidas! Por favor, lee la [Guía de Contribución](CONTRIBUTING.md) antes de enviar una solicitud de extracción (_pull request_).

## 🛡️ Seguridad

Si descubres una vulnerabilidad de seguridad, revisa nuestra [Política de Seguridad](SECURITY.md) para reportarla de manera segura.

## 📄 Licencia

Distribuido bajo la Licencia MIT. Consulta el archivo `LICENSE` para obtener más información.
