# tp0

Este es el trabajo practico 0 de "Ingenieria de Software 2" catedra Rojas.  
Alumno: Tomas Benitez Potochek, padron 100862

Este trabajo es un simple servidor que responde a una api REST que modela un conjunto reducido de operaciones similes 
a un servicio de ecommerce, principalmente la sube, baja y actualización de productos en el sistema, asi como el agregado y quitado de productos a carritos de compras de usuarios.  
El trabajo esta llevado a cabo en el lenguaje funcional Haskell, usando la librería [`servant`](https://docs.servant.dev/en/latest/index.html) para la definición de endpoints, la cual por debajo usa muchas otras librerias como `Warp`, que es el servidor http, `aeson` para el parseo y generación de JSON, y muchas otras.  
Para el modelo de persistencia, este projecto usa la librería `persistent` junto con el backend postgresql para la base de datos concreta.  
Para modelar logica de negocios, una libreria muy util que surge aquí es [`Polysemy`](https://github.com/polysemy-research/polysemy#readme). Esta es una librería de "efectos algebraicos" de alto orden.

Las rutas se definen en`API.Routes` y los DTOs asociados en `API.DTO`  
`App` contiene las definiciones de los efectos de los repositorios, definiciones de los objetos que representan el cuerpo de ciertos requests en el dominio, y los handlers que representan la logica de negocio para cada request de nuestra api.  
El modulo `Domain` tiene las entidades del dominio que tienen contracara en la base de datos.  
El modulo `Infra/Persistence` contiene los intérpretes de los efectos de repositorio que son ejecutados contra la base de datos postgresql. Contiene tambien las definiciones de las tablas de la base de datos.

## Complicaciones

Lo más complicado fue lograr un entorno de desarrollo completo, eficiente y simple de usar, mediante docker y docker-compose al mismo tiempo que debia entender las interacciones de docker con el tooling the haskell. La verdad que aún con todo el tiempo invertido leyendo y probando distintas cosas, no considero que cumplí con ese objetivo por completo, pero considero que no fue un completo fracaso.  
La idea era poder compilar y ejecutar todo el proyecto con una simple invocacion de docker compose, de manera que se pueda cachear lo mas posible y evitar reconstruir la mayor cantidad de capas y asi tener tambien una manera simple de correr las pruebas en pipeline de github.  
El resultado fue que es posible compilar, correr la aplicacion y los tests con un par de invocaciones de docker compose, pero debido a la manera que la herramienta stack compila y corre los tests, se lleva a cabo mucha invalidacion de cache. Logré mejor la situacion un poco en mi ambiente local de docker usando volumenes que cachean los artefactos de compilacion, pero esto no sirve para los pipelines. Por este motivo, los pipelines tardan 42 minutos en correr. Tambien es posible que algunos de mis intentos de mejorar la situacion de los pipelines la haya empeorado. El .github/ci.yml actual no tiene mucho sentido aunque tecnicamente funciona. Me hubiera gustado poder experimentar mas con esto y lograr que no se invaliden los caches, pero me consumian mucho mas tiempo de lo que planeaba gastar en esto.

## testing
los tests estan escritos con la ayuda de las bibliotecas [`hspec`](https://hspec.github.io/), [`hspec-wai`](https://hackage.haskell.org/package/hspec-wai-0.11.1/docs/Test-Hspec-Wai.html). Tambien se hace uso de `servant-client` para generar automaticamente clientes http que siguen la descripción de nuestra API definida en API.Routes

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

### docs
se puede ver el esquema de la api levantando el servidor y llamando al endpoint `/openapi.json`

## desafíos

### middleware
para logging the llamadas a endpoints

### mejoras?
* Los campos internos de los objetos de dominio podrian no exportarse y en vez de eso exportar un patron unidireccional que permite inspeccionar los campos pero no construir un objeto de dominio a partir de las partes, ya que eso puede violar invariantes.
* mejores nombres de modulos y mejor organizacion jerárquica, ya que algunas cosas que estan en un modulo podrian estar en otro o podrian combinarse.
* transaction rollback por cada test de integración. Intenté hacer esto pero no era trivial con esta libreria de persistencia. La libreria tiene primitivas de transaccion, pero solo lograba que corrar un test suite en una transaccion, 
no cada test.
* evitar la invalidacion de cache al correr `stack test` para poder usar los caches nativos de docker con buildkit en vez de volumenes. Esto deberia simplificar el setup, mejorar el determinismo e incluso lograr que los pipelines corran muchisimo más rapido (usando el cache buildkit the github actions)
* algo mas de modularidad en distintos modulos, como Lib.hs que quedó con muchas mas cosas de las que quería.
  
### docker compose
tenemos

### github ci/cd
tenemos un pipeline que instala todas las dependencias, compila el projecto y ejecuta todos los tests.  
El problema es que no logra cachear nada si bien usa docker y tarda un periodo de tiempo intolerable de más de 40 minutos. Por un lado, la imagen con las herramientas de compilacion es pesada. Por otro lado, el cache se invalida y no logré solucionarlo, entonces siempre corre desde 0. Existen tambien alternativa sin docker para compilar pero igual son pesadas y no quería pasar más tiempo lidiando con problemas de ci dado el tiempo que teniamos para esta entrega.  
Lo bueno es que el dockerfile esta armado para que genere una imagen muy liviana como runtime. Una vez compilado, esa imagen podria subrse a algun repositorio de imagenes docker y desplegarlo en un ambiente real (ej en digital ocean con kubernetes). Aunque tampoco tengo demasiada experiencia en eso tampoco.

## notas finales
tenía mas para decir aca de por qué elegí haskell y por qué especificamente elegí servant y polysemy, este documento es ya muy largo y la idea era ser breve.