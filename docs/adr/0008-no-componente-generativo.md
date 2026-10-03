# ADR 0008: No incorporar un componente generativo en ROUTB

## Estado

Aceptado para la versión actual del proyecto.

## Contexto

La evaluación de semana 9 pide valorar si ROUTB debe integrar un componente generativo. La IA apoya el desarrollo, pero eso no implica que el producto deba enviar datos de viajes o usuarios a un modelo en tiempo de ejecución.

## Decisión

ROUTB **no integrará un componente generativo en producción** en el alcance académico actual. Se compararon tres candidatos según necesidad, costo y latencia:

| Candidato | Necesidad en ROUTB | Costo esperado | Efecto de latencia | Decisión |
|---|---|---|---|---|
| Chatbot de soporte | Bajo: los flujos actuales son acotados y se pueden explicar con ayuda estática. | Recurrente y variable por proveedor/uso; también requiere operar la integración. | Cada consulta depende de una llamada externa y su disponibilidad. | No implementar. |
| Resumen generativo de viajes | Bajo: origen, destino, hora y cupos ya se presentan como datos estructurados. | Variable por volumen, sin beneficio suficiente para justificar el consumo. | Añade una llamada antes de mostrar información que ya existe. | No implementar. |
| Clasificación generativa de motivos de rechazo | Bajo: el conductor ya decide aceptar o rechazar; inferir razones no forma parte del flujo. | Variable y asociado a procesar texto que podría contener datos personales. | Añade espera y una decisión probabilística a una operación de respuesta inmediata. | No implementar. |

El presupuesto operativo objetivo es $0 USD y la búsqueda/reserva debe conservar el p95 publicado de menos de 3,99 s. Una llamada remota no ofrece una garantía que permita atribuir cumplimiento a ROUTB y puede aumentar latencia y dependencia externa. No se estiman precios puntuales: dependen del proveedor, modelo y volumen, y no son necesarios para concluir que estos casos no justifican el costo.

## Alternativas consideradas

1. Añadir uno de los tres componentes generativos y aceptar el costo, la latencia y la gestión de datos externos.
2. Mantener los flujos deterministas y usar IA solo como apoyo al análisis, implementación y documentación.

Se elige la alternativa 2. Las decisiones de disponibilidad, aceptación, rechazo y cancelación siguen reglas explícitas del backend; ningún modelo decide ni ejecuta esas operaciones.

## Consecuencias

- No se transmiten prompts ni datos de viaje a un proveedor de IA en runtime.
- No se suma una dependencia de inferencia, una clave de proveedor o un costo variable al despliegue.
- La experiencia no ofrece chatbot ni contenido generativo; las pantallas presentan los datos existentes.
- La decisión se puede reconsiderar si aparece una necesidad validada, un presupuesto y un escenario de latencia medido.
