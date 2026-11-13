# Attacking (WoW Forever)

Cuánto falta para tu siguiente golpe, de forma cómoda y poco intrusiva. Cada arma tiene su pieza y su color: **dorada** la mano derecha, **azul** la mano izquierda (si llevas dos armas) y **verde** el disparo (Disparo automático o varita). Al estar listo el golpe da un destello suave.

## Instalación
1. Copia la carpeta para que quede `World of Warcraft\_forever_\Interface\AddOns\Attacking\Attacking.toc`.
2. **Activa la barra de golpe en los ajustes del juego** (Attacking lee su avance; ver «Cómo cuenta»).
3. Reinicia el juego (los addons solo cargan al arrancar).
4. Ajustes: `/attacking` o **Opciones > AddOns > Attacking**. Mientras están abiertos se ve una vista previa, para ver cada cambio al momento.

## Estilos
| Estilo | Cómo se ve |
|---|---|
| **Icono** | El icono del arma se rellena de abajo arriba. |
| **Reloj** | El icono del arma con una sombra que gira, como el tiempo de reutilización de una habilidad. |
| **Barra** | Una barra fina con un brillo que avanza. La más discreta. Los segundos, a su derecha. |
| **Puntos** | Cinco puntos que se encienden según carga el golpe. Los segundos, a su derecha. |

En Icono y Reloj se elige el dibujo: el arma que llevas equipada o una espada (y un arco para el disparo).

## Ajustes
- **Cuándo se ve**: mientras atacas (por defecto), en combate (aunque no estés pegando) o siempre (fuera de combate se ve lleno). La pieza de disparo, sin estar disparando, solo sale en los dos últimos modos y si eres cazador con arma a distancia.
- **Tamaño** y **opacidad** (20–100 %).
- Segundos que faltan, destello, piezas de mano izquierda y de disparo.
- **Ocultar la barra de golpe de Blizzard** (en pruebas, desactivado): la vuelve invisible pero sigue funcionando.
- **Resultado del golpe** (activado): junto a la pieza sale un momento, con su color, qué le ha pasado a tu objetivo: ¡Fallo!, Esquivado, Parado, Bloqueado, Desviado, Absorbido, Resistido, Inmune, Evade y, si quieres, ¡Crítico! y Rozado. Los golpes normales no enseñan nada. Puede ir al lado (en barra y puntos, detrás de los segundos) o encima.
  - El juego dice qué le pasa a tu objetivo pero no quién le ha atacado. Si coincide con el reinicio de tu barra de golpe, es tuyo y sale en la pieza de esa mano (también en grupo). Si no coincide con nada (por ejemplo, una habilidad que falla), solo sale yendo solo, salvo que marques «En grupo, también los que no coinciden».

## Colocar las piezas
- `/attacking mover` (o «Desbloquear para mover»): cada pieza sale con un recuadro azul y su nombre y **se arrastra por separado**. Clic derecho en cualquiera (o «Fijar las piezas») las deja fijas; fijas no reciben clics.
- **Cuadrícula**: se ve por toda la pantalla al mover, con las líneas centrales en rojo. Con el **imán**, al soltar una pieza se pega a la línea más cercana su borde o su centro (lo que esté más cerca). **Mayús** al soltar = sin ajustar. Cuadrícula, imán y tamaño de las casillas (8–64 px) se eligen en los ajustes.
- «Volver a su sitio» o `/attacking reset` las recoloca (iconos en fila; barras y puntos uno debajo de otro).
- `/attacking prueba` enciende o apaga la vista previa sin abrir los ajustes.

## Cómo cuenta
WoW Forever pone varias limitaciones a los addons (vistas probando en el juego):
- **No se puede leer el registro de combate** (el juego lo bloquea con un aviso), así que Attacking no sabe por su cuenta cuándo golpeas. Lo que hace es **leer el avance de la barra de golpe del propio juego** (`SwingTimerMainHandFrame`, `SwingTimerRangedFrame` y, si existe, la de la mano izquierda). Por eso esa barra tiene que estar activada en los ajustes del juego.
- La barra del juego va de 0 a 1 y en combate la velocidad de ataque es «secreta» para los addons. Los segundos se calculan **midiendo el ritmo de la propia barra** desde el último golpe, así que notan los cambios de velocidad (Aluvión…). Solo al principio de cada golpe se usa la velocidad leída fuera de combate.
- **Manda la barra del juego**: mientras se mueve, la pieza se va cargando con sus segundos; si lleva medio segundo quieta (sin atacar, objetivo fuera de alcance o huyendo), la pieza se ve **llena**: el golpe está listo y saldrá en cuanto lo tengas a tiro. Así no depende de que el juego avise de que empiezas a atacar (ese aviso se pierde, por ejemplo, si ya atacabas al hacer `/reload`).
- Los textos de resultado salen al instante si coinciden con tu golpe; si no, como mucho 0,1 s después yendo solo.
- La barra de disparo del juego está visible aunque no dispares: la pieza de disparo solo sale cuando el juego avisa de que empiezas a disparar.
- Por las mismas limitaciones se quitó el seguimiento de buffos y debuffos (en combate no se pueden leer).
- El resultado del golpe sale de `UNIT_COMBAT`, que Forever sí permite (lo que le pasa a tu objetivo).
- `/attacking debug` escribe 5 segundos en el chat lo que se lee de las barras del juego y si el addon cree que atacas (para diagnosticar).

## Datos guardados
- `AttackingDB` (toda la cuenta): estilo, posiciones, tamaño y opciones.
