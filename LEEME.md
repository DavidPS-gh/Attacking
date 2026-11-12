# Attacking (WoW Forever)

El tiempo hasta tu siguiente golpe, como un icono que se va rellenando: gris justo después de golpear y a todo color cuando el siguiente está listo (con un destello).

**Cuándo se ve** (en los ajustes): **mientras atacas** (por defecto: con el ataque automático puesto o disparando), **en combate** (aunque no estés pegando) o **siempre** (fuera de combate se ve lleno: el golpe está listo). En los dos últimos modos, el icono de disparo solo sale sin estar disparando si eres cazador con arma a distancia.

## Instalación
1. Copia la carpeta para que quede `World of Warcraft\_forever_\Interface\AddOns\Attacking\Attacking.toc`.
2. Reinicia el juego (los addons solo cargan al arrancar).
3. Ajustes: `/attacking` o **Opciones > AddOns > Attacking**. Mientras están abiertos se ve una vista previa del icono (y de los buffos y debuffos) por encima de la ventana de opciones, para ver cada cambio al momento.

## Uso
- **Colocarlo**: `/attacking mover` (o el botón «Desbloquear para mover»). Cada pieza sale con un recuadro azul y su nombre (mano derecha, mano izquierda, disparo, mis buffos, debuffos del objetivo) y **se arrastra por separado** a donde quieras. Clic derecho en cualquiera (o «Fijar las piezas») las deja fijas; fijas no reciben clics, así que no estorban. «Volver a su sitio» o `/attacking reset` las recoloca todas. `/attacking prueba` enciende o apaga la vista previa sin abrir los ajustes.
- **Opacidad**: barra en los ajustes (20–100 %) para los iconos y las filas de buffos, para que estorben menos. Mientras mueves las piezas se ven opacas para colocarlas bien.
- **Iconos**:
  - Mano derecha: mientras atacas cuerpo a cuerpo.
  - Mano izquierda (opcional), algo más pequeño: si llevas dos armas.
  - Disparo (opcional): mientras disparas con Disparo automático o con una varita.
- **Opciones**: tamaño, segundos que faltan debajo del icono, destello al estar listo, y el dibujo del icono (el arma que llevas equipada o una espada/arco).
- **Resultado del golpe** (opcional): junto a cada icono sale un momento, con su color, qué ha pasado: ¡Fallo!, Esquivado, Parado, Bloqueado, Desviado, Absorbido, Resistido, Inmune, Evade y, si quieres, ¡Crítico! y Rozado. Los golpes normales no enseñan nada. Puede salir al lado del icono (los iconos se separan para dejar sitio al texto) o encima. En modo mover se ve un texto de prueba.

## Buffos y debuffos
Ajustes en **Opciones > AddOns > Attacking > Buffos y debuffos**.

**Limitación de Forever:** en combate el juego no deja a los addons leer buffos ni debuffos (son «secretos»), y tampoco sirve leer los iconos de buffos de arriba a la derecha (llevan los mismos datos bloqueados). Lo que hace Attacking es **recordar lo que había al empezar el combate y seguir contando**: los buffos que ya tenías (y los debuffos que tuviera tu objetivo) siguen a la vista, vaciándose, y desaparecen al acabarse. Lo que no se ve en combate: los buffos que consigas durante la pelea (Enfurecer, Ira desatada…) ni si alguno se quita antes de tiempo. Si cambias de objetivo en combate, la fila de debuffos se vacía hasta salir de combate.
- **Mis buffos**: una fila de iconos debajo del golpe con los buffos de tu lista que tengas puestos. Cada icono se vacía según se acaba, con el tiempo que le queda debajo y las acumulaciones en la esquina.
- **En el objetivo**: otra fila debajo (borde rojo) con los debuffos de tu lista que tenga tu objetivo enemigo. «solo míos» hace que solo cuente el que hayas puesto tú (tu Desgarrar, no el de otro guerrero).
- Cada fila se activa o desactiva con su casilla. **Cuándo se ven**: mientras atacas (como el icono del golpe), en combate o siempre. También se elige el tamaño de los iconos.
- **Listas**: son de cada personaje y la primera vez se rellenan con una propuesta para tu clase («Lista de mi clase» la vuelve a poner). Se añade por el nombre del hechizo tal y como sale en el juego, o por su número; la «x» lo quita. Caben 12 en cada lista.
- En modo mover se ven los primeros de cada lista con un tiempo de prueba.

## Cómo cuenta
- En WoW Forever los addons **no pueden leer el registro de combate** (el juego lo bloquea), así que Attacking no sabe por su cuenta cuándo golpeas. Lo que hace es **leer el avance de la barra de golpe del propio juego** (`SwingTimerMainHandFrame`, `SwingTimerRangedFrame` y, si existe, la de la mano izquierda) y enseñarlo en el icono.
- **Por eso la barra de golpe del juego tiene que estar activada** en sus ajustes. La casilla «Ocultar la barra de golpe de Blizzard» (desactivada por defecto, en pruebas) la vuelve invisible, pero sigue funcionando por debajo. En la 0.4.0 esa opción se aplicaba en cada fotograma y provocaba tirones y sonido entrecortado; ahora solo se aplica una vez.
- Los segundos que faltan se calculan con tu velocidad de ataque. En combate esa velocidad es «secreta» para los addons, así que se usa la última leída fuera de combate (no nota cambios de velocidad a mitad de pelea).
- Si no hay barra del juego, el disparo cuenta con cada Disparo automático o «Disparar» de varita; el golpe cuerpo a cuerpo no se puede contar.
- **Resultado del golpe**: sin registro de combate no hay de dónde sacarlo, así que de momento no sale (pendiente de probar otra vía).

## Datos guardados
- `AttackingDB` (toda la cuenta): posición, tamaño y opciones.
- `AttackingCharDB` (por personaje): las listas de buffos y debuffos que se siguen.
