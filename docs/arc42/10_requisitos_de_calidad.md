# 10. Requisitos de calidad

Esta sección documenta los atributos de calidad fundamentales para la correcta operación y evolución de ROUTB. Además, se priorizan las metas del sistema con el Árbol de Utilidad y se definen escenarios concretos para evaluar la arquitectura.

## 10.1 Resumen de los requisitos de calidad — Árbol de utilidad

El siguiente árbol de utilidad representa los principales atributos de calidad de ROUTB y sus respectivos subatributos:

```mermaid
flowchart LR
    U["Utilidad<br/>ROUTB"]

    REND["Rendimiento"]
    SEG["Seguridad"]
    DISP["Disponibilidad"]
    ESC["Escalabilidad"]
    POR["Portabilidad"]
    MANT["Mantenibilidad"]
    PRIV["Privacidad"]
    USA["Usabilidad"]

    U --> REND
    U --> SEG
    U --> DISP
    U --> ESC
    U --> POR
    U --> MANT
    U --> PRIV
    U --> USA

    REND --> REND1["Tiempo de búsqueda"]
    REND1 --> REND1O["Objetivo: ≤ 2 s"]
    REND --> REND2["Cupos en tiempo real"]
    REND2 --> REND2O["Actualiza al instante"]

    SEG --> SEG1["Credenciales"]
    SEG1 --> SEG1O["Hashing con salt"]
    SEG --> SEG2["Comunicación"]
    SEG2 --> SEG2O["Cifrado HTTPS"]

    DISP --> DISP1["Franjas de alta demanda"]
    DISP1 --> DISP1O["Objetivo: ≥ 99 %"]

    ESC --> ESC1["Crecimiento de usuarios"]
    ESC1 --> ESC1O["Rendimiento estable"]

    POR --> POR1["Compatibilidad"]
    POR1 --> POR1O["Igual en Android/iOS"]

    MANT --> MANT1["Modularidad del backend"]
    MANT1 --> MANT1O["Cambios aislados"]

    PRIV --> PRIV1["Datos personales"]
    PRIV1 --> PRIV1O["Cumple Ley 1581 de 2012"]

    USA --> USA1["Acciones principales"]
    USA1 --> USA1O["Máximo 3 pasos"]
```

## 10.2 Escenarios de calidad

| Atributo de calidad | Fuente del estímulo | Estímulo | Artefacto | Entorno | Respuesta | Medida de respuesta |
|---|---|---|---|---|---|---|
| **Rendimiento** | Pasajero | Consulta los viajes disponibles | ROUTB | Condiciones normales de operación | El sistema procesa la solicitud y muestra los resultados | El 95 % de las solicitudes responde en menos de 2 segundos |
| **Usabilidad** | Pasajero | Desea reservar un viaje disponible | ROUTB | Uso normal de la aplicación móvil | El sistema permite completar la reserva mediante un proceso sencillo | La reserva se completa en un máximo de 3 pasos principales |
| **Seguridad** | Atacante | Intenta interceptar las comunicaciones o acceder a las contraseñas almacenadas | ROUTB | En cualquier momento | Las contraseñas permanecen protegidas mediante hashing con salt y las comunicaciones viajan cifradas | El 100 % de las contraseñas se almacena con hashing y salt, y el 100 % del tráfico usa HTTPS |
| **Disponibilidad** | Estudiante | Accede a la plataforma para consultar o reservar un viaje | ROUTB | Franjas de mayor demanda | Las funcionalidades principales permanecen disponibles | Disponibilidad mínima del 99 % durante las franjas de mayor demanda |
| **Escalabilidad** | Usuarios del sistema | Aumento progresivo de usuarios, viajes y reservas | ROUTB | Periodos de alta demanda | El sistema mantiene su operación normal | Soporta hasta 100 usuarios concurrentes sin errores ni interrupciones |

---
