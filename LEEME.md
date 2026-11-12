# Attacking (WoW Forever)

El tiempo hasta tu siguiente golpe, como un icono que se va rellenando: gris justo después de golpear y a todo color cuando el siguiente está listo (con un destello). Solo aparece mientras atacas.

## Instalación
1. Copia la carpeta para que quede `World of Warcraft\_forever_\Interface\AddOns\Attacking\Attacking.toc`.
2. Reinicia el juego (los addons solo cargan al arrancar).
3. Ajustes: `/attacking` o **Opciones > AddOns > Attacking**.

## Uso
- **Colocarlo**: `/attacking mover` (o el botón «Desbloquear para mover»). Se ven todos los iconos rellenándose de prueba; arrástralos y pulsa clic derecho (o «Fijar en su sitio») para dejarlos fijos. Fijo no recibe clics, así que no estorba. `/attacking reset` lo devuelve al centro.
- **Iconos**:
  - Mano derecha: mientras atacas cuerpo a cuerpo.
  - Mano izquierda (opcional), algo más pequeño: si llevas dos armas.
  - Disparo (opcional): mientras disparas con Disparo automático o con una varita.
- **Opciones**: tamaño, segundos que faltan debajo del icono, destello al estar listo, y el dibujo del icono (el arma que llevas equipada o una espada/arco).
- **Resultado del golpe** (opcional): junto a cada icono sale un momento, con su color, qué ha pasado: ¡Fallo!, Esquivado, Parado, Bloqueado, Desviado, Absorbido, Resistido, Inmune, Evade y, si quieres, ¡Crítico! y Rozado. Los golpes normales no enseñan nada. Puede salir al lado del icono (los iconos se separan para dejar sitio al texto) o encima. En modo mover se ve un texto de prueba.

## Buffos y debuffos
Ajustes en **Opciones > AddOns > Attacking > Buffos y debuffos**.
- **Mis buffos**: una fila de iconos debajo del golpe con los buffos de tu lista que tengas puestos. Cada icono se vacía según se acaba, con el tiempo que le queda debajo y las acumulaciones en la esquina.
- **En el objetivo**: otra fila debajo (borde rojo) con los debuffos de tu lista que tenga tu objetivo enemigo. «solo míos» hace que solo cuente el que hayas puesto tú (tu Desgarrar, no el de otro guerrero).
- Cada fila se activa o desactiva con su casilla. **Cuándo se ven**: mientras atacas (como el icono del golpe), en combate o siempre. También se elige el tamaño de los iconos.
- **Listas**: son de cada personaje y la primera vez se rellenan con una propuesta para tu clase («Lista de mi clase» la vuelve a poner). Se añade por el nombre del hechizo tal y como sale en el juego, o por su número; la «x» lo quita. Caben 12 en cada lista.
- En modo mover se ven los primeros de cada lista con un tiempo de prueba.

## Cómo cuenta
- Empieza de nuevo con cada golpe tuyo, también si fallas o te lo esquivan, y con los ataques que sustituyen al golpe normal (Golpe heroico, Rajar, Golpe de raptor, Magullar).
- Si cambia tu velocidad de ataque a mitad de golpe (Ira desatada, abalorios…), se ajusta en el momento.
- Cuando paras un ataque, tu siguiente golpe se adelanta (40 % de tu velocidad, sin bajar del 20 % restante), como en el juego.
- A distancia empieza a contar con cada Disparo automático o «Disparar» de varita.

## Datos guardados
- `AttackingDB` (toda la cuenta): posición, tamaño y opciones.
- `AttackingCharDB` (por personaje): las listas de buffos y debuffos que se siguen.
