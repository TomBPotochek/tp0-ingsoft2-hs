# tp0

## Comandos comunes

- Iniciar la app de la API: `make app`
- Ejecutar tests unitarios: `make unit`
- Ejecutar tests de integración: `make integration`
- Ejecutar tests e2e: `make e2e`
- Detener stack normal: `make down`
- Detener stack de integración: `make down-integration`
- Detener stack e2e: `make down-e2e`
- Eliminar contenedores y volúmenes: `make clean`

La app está expuesta en `http://localhost:8080`.

## Guía de desarrollo local

Este proyecto soporta un flujo de trabajo local con Stack para herramientas de desarrollo
(plugin Polysemy y generación de Haddock) sin afectar los builds de Docker.

Estas herramientas no son necesarias para construir el proyecto con Docker y ejecutar los tests, pero son útiles durante el desarrollo y solo agregarían peso y complejidad al build de Docker.

### Herramientas de build

La herramienta principal necesaria es [ghcup](https://www.haskell.org/ghcup/). Si también desarrollas en VSCode, instala la [extensión oficial de Haskell](https://marketplace.visualstudio.com/items?itemName=haskell.haskell) y, si es necesario, configura la ruta al binario de ghcup. Eso debería ser suficiente, ya que la extensión puede detectar qué herramientas y versiones necesita descargar mediante ghcup (te pedirá permiso).  
Si eso no funciona, al momento de escribir esto, el proyecto utiliza:
- Stack 3.7.1
- Cabal 3.14.2.0
- GHC 9.10.3
- HLS 2.13.0

Y puedes descargarlas manualmente con ghcup ejecutando en tu terminal `ghcup tui`

### Comandos locales

- Build local con el plugin Polysemy: `make local-build`
- Construir solo la documentación del proyecto (liviano): `make local-docs-project`
- Construir documentación incluyendo dependencias (pesado): `make local-docs`

`make local-build` y los targets de docs primero ejecutan `local-bootstrap`, que asegura que
`polysemy-plugin` esté instalado en el snapshot local.
