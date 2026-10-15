# Mente en Movimiento 3D — Godot 4

Prototipo 3D estilizado de runner educativo, construido con GDScript y geometría procedural para no depender de modelos externos.

## Abrir
1. Descomprime `mente_en_movimiento_3d_godot4.zip`.
2. En Godot 4, pulsa **Importar** y selecciona `project.godot`.
3. Abre el proyecto y ejecuta con **F6/F5** (F5 ejecuta el proyecto principal).

## Controles
- `A` / `←`: carril izquierdo.
- `D` / `→`: carril derecho.
- `Espacio` / `W` / `↑`: saltar.
- `S` / `↓`: deslizarse.
- Responde las preguntas mediante los botones de pantalla.
- `Enter`: reiniciar tras terminar la partida.

## Contenido del prototipo
- Escena `Player.tscn` basada en `CharacterBody3D`.
- Personaje procedural con uniforme azul UTSC y guía verde.
- Cámara en tercera persona, iluminación y pasillo 3D.
- Cinco ambientes visuales que cambian con el progreso.
- Obstáculos, botellas de agua, vitalidad, enfoque y trivia educativa.
- Encuentro básico con El Sedentarismo en el nivel 5.

## Alcance y limitaciones
Esta es una primera versión jugable para validar la dirección 3D, no una versión final con arte profesional. Los modelos están hechos con primitivas 3D y los obstáculos se detectan mediante carril y distancia para mantener la lógica sencilla. Las cinco zonas y el jefe tienen una primera implementación; todavía requieren pruebas, balance y arte definitivo. El prototipo 2D original no se incluye ni se modifica.
