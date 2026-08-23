# 0001 - Arquitectura de monolito modular para el backend de ROUTB

## Estado

Propuesto

## Contexto

ROUTB es una plataforma de movilidad colaborativa para estudiantes universitarios, desarrollada por un equipo de cuatro integrantes dentro del alcance de un proyecto académico. El sistema debe soportar funcionalidades como registro/login, publicación y búsqueda de recorridos, gestión de cupos y solicitudes, notificaciones, historial, reputación y un panel administrativo con estadísticas.

Era necesario definir la estrategia general de organización del backend antes de avanzar con el diseño detallado, considerando el tamaño del equipo, el tiempo disponible, la necesidad de trabajo paralelo entre los integrantes y el alcance real del proyecto (una comunidad universitaria, sin procesamiento de pagos ni operación a gran escala).

## Decisión

Para ROUTB se utilizará una arquitectura de **monolito modular**: el backend se mantiene como una única aplicación desplegable, pero organizada internamente en módulos independientes según las funcionalidades del sistema.

Se elige este enfoque porque:

- Mantiene una arquitectura sencilla, adecuada al alcance del proyecto.
- Facilita el mantenimiento y las pruebas al tener límites claros entre módulos.
- Permite el trabajo paralelo de los cuatro integrantes del equipo, cada uno pudiendo enfocarse en uno o más módulos sin generar conflictos constantes.
- Evita la complejidad operativa de una arquitectura distribuida o de microservicios (despliegue múltiple, comunicación entre servicios, consistencia distribuida) que no se justifica para el tamaño actual del sistema.
- Deja abierta la posibilidad de evolucionar hacia una arquitectura distribuida en el futuro si el crecimiento del sistema lo requiere, ya que los módulos están desacoplados internamente.

## Alternativas consideradas

### Arquitectura de microservicios

- **Ventajas:** escalabilidad independiente por servicio, despliegues independientes, aislamiento de fallos.
- **Desventajas:** alta complejidad operativa (orquestación, comunicación entre servicios, monitoreo distribuido), sobrecarga innecesaria para un equipo de cuatro personas y un proyecto de alcance académico, mayor tiempo de configuración inicial que resta tiempo al desarrollo de funcionalidades.
- **Motivo de descarte:** la complejidad no se justifica frente al tamaño del equipo, el tiempo disponible y el volumen de usuarios esperado.

### Arquitectura por capas
 
- **Ventajas:** separación clara de responsabilidades por capa (presentación, lógica de negocio, acceso a datos), enfoque conocido y sencillo de implementar, buena curva de aprendizaje para el equipo.
- **Desventajas:** la organización por capas horizontales (en lugar de por funcionalidad) dificulta el trabajo paralelo de los cuatro integrantes, ya que una misma funcionalidad (por ejemplo, gestión de cupos) queda repartida entre varias capas y distintos desarrolladores terminan tocando los mismos archivos; además tiende a generar alto acoplamiento entre funcionalidades dentro de cada capa y dificulta el mantenimiento y las pruebas a medida que el sistema crece.
- **Motivo de descarte:** dificulta el trabajo paralelo del equipo al no aislar las funcionalidades entre sí y compromete el mantenimiento a mediano plazo.


## Consecuencias

**Positivas:**

- Un único despliegue simplifica la infraestructura y el proceso de entrega para el equipo.
- La organización por módulos permite asignar responsabilidades claras a cada integrante.
- Las pruebas pueden aislarse por módulo, facilitando la detección temprana de errores.
- El sistema queda mejor preparado para una eventual migración a microservicios si el proyecto escalara más allá del alcance académico.

**Negativas / riesgos:**

- Se requiere definir y respetar límites claros entre módulos (por ejemplo, evitar dependencias circulares o accesos directos entre módulos que rompan el aislamiento).
- Al ser un único desplegable, un error grave en un módulo puede afectar la disponibilidad de toda la aplicación.
- Se necesita disciplina del equipo para no degradar la modularidad con el tiempo ("monolito modular" puede convertirse en "monolito enredado" si no se cuida el diseño).

## Matriz de decisión

Comparación de los tres estilos arquitectónicos contra los escenarios de calidad definidos en el árbol de utilidad del proyecto.

| Criterio (árbol de utilidad) | Monolito modular | Arquitectura por capas | Microservicios |
|---|---|---|---|
| Rendimiento | Favorece: sin latencia de red entre módulos | Neutral: sin latencia de red, pero el acoplamiento interno puede degradar con el crecimiento | Perjudica: latencia de red entre servicios |
| Seguridad | Favorece: autenticación centralizada, fácil de auditar | Favorece: centralizada en la capa correspondiente | Perjudica: requiere replicar o coordinar autenticación entre servicios |
| Disponibilidad | Neutral: un fallo grave puede afectar todo el desplegable | Neutral: mismo riesgo que el monolito modular | Favorece: aislamiento de fallos por servicio, pero mayor complejidad operativa para lograrlo |
| Escalabilidad | Favorece: suficiente para el alcance actual; permite extraer módulos a futuro si crece | Perjudica: el acoplamiento por capas dificulta escalar partes específicas | Favorece: escalado independiente por servicio, mayor rango a futuro |
| Mantenibilidad | Favorece: módulos por dominio con responsabilidades claras, aíslan cambios y pruebas | Perjudica: una misma funcionalidad queda repartida entre capas, dificultando el aislamiento de cambios | Favorece: aislamiento total entre servicios, pero con sobrecarga operativa alta |

**Resultado:** el monolito modular obtiene el mejor balance entre los criterios priorizados por el equipo, sin sacrificar de forma crítica escalabilidad ni disponibilidad para el tamaño esperado del sistema.
