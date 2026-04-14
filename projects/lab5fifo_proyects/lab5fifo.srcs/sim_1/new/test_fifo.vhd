-------------------------------------------------------------------
--
--  Fichero:
--    fifo_tb.vhd
--
--  Prop¨®sito:
--    Testbench para la FIFO (fifoQueue)
--
--  Descripci¨®n:
--    - Reloj de 100 MHz (periodo 10 ns)
--    - FIFO de 8 bits de ancho y profundidad 4 (configurable)
--    - Prueba de reset, escritura/lectura, llenado, vaciado,
--      operaciones simult¨¢neas, y wrap-around.
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;  -- para log2 (si se usa)

entity fifo_tb is
end fifo_tb;

architecture sim of fifo_tb is

  -- Constantes
  constant WL         : natural := 8;
  constant DEPTH      : natural := 4;          -- profundidad peque?a para probar wrap
  constant CLK_PERIOD : time    := 10 ns;

  -- Se?ales del DUT (Device Under Test)
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal wrE     : std_logic := '0';
  signal dataIn  : std_logic_vector(WL-1 downto 0) := (others => '0');
  signal rdE     : std_logic := '0';
  signal dataOut : std_logic_vector(WL-1 downto 0);
  signal numData : std_logic_vector(log2(DEPTH)-1 downto 0);
  signal full    : std_logic;
  signal empty   : std_logic;

  -- Procedimiento para verificar valores con mensaje
  procedure check_equal(
    actual   : in std_logic_vector;
    expected : in std_logic_vector;
    msg      : in string
  ) is
  begin
    assert actual = expected
      report msg & " - Esperado: " & integer'image(to_integer(unsigned(expected))) &
             ", Obtenido: " & integer'image(to_integer(unsigned(actual)))
      severity error;
  end procedure;

  procedure check_equal(
    actual   : in std_logic;
    expected : in std_logic;
    msg      : in string
  ) is
  begin
    assert actual = expected
      report msg & " - Esperado: " & std_logic'image(expected) &
             ", Obtenido: " & std_logic'image(actual)
      severity error;
  end procedure;

  procedure check_equal(
    actual   : in integer;
    expected : in integer;
    msg      : in string
  ) is
  begin
    assert actual = expected
      report msg & " - Esperado: " & integer'image(expected) &
             ", Obtenido: " & integer'image(actual)
      severity error;
  end procedure;

begin

  -- Instancia de la FIFO
  uut: entity work.fifoQueue
    generic map (
      WL    => WL,
      DEPTH => DEPTH
    )
    port map (
      clk     => clk,
      rst     => rst,
      wrE     => wrE,
      dataIn  => dataIn,
      rdE     => rdE,
      dataOut => dataOut,
      numData => numData,
      full    => full,
      empty   => empty
    );

  -- Generaci¨®n del reloj
  clk_process : process
  begin
    clk <= '0';
    wait for CLK_PERIOD/2;
    clk <= '1';
    wait for CLK_PERIOD/2;
  end process;

  -- Proceso de estimulos
  stim_proc: process
    variable num_int : integer;
  begin
    -- Inicialmente en reset
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait until rising_edge(clk);

    report "=== Inicio de la simulaci¨®n ===";

    -----------------------------------------------------------------
    -- Verificaci¨®n del reset
    check_equal(empty,   '1', "Reset: empty debe ser 1");
    check_equal(full,    '0', "Reset: full debe ser 0");
    check_equal(numData, std_logic_vector(to_unsigned(0, numData'length)), "Reset: numData debe ser 0");

    -----------------------------------------------------------------
    -- Escritura de un dato
    dataIn <= x"AA";
    wrE    <= '1';
    wait until rising_edge(clk);
    wrE    <= '0';
    wait for 1 ns;  -- peque?o retraso para permitir actualizaci¨®n de se?ales

    check_equal(empty,   '0', "Despu¨¦s de escribir 1: empty debe ser 0");
    check_equal(full,    '0', "Despu¨¦s de escribir 1: full debe ser 0");
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, 1, "Despu¨¦s de escribir 1: numData debe ser 1");

    -- Verificar que la lectura devuelve el dato correcto
    rdE <= '1';
    wait until rising_edge(clk);
    rdE <= '0';
    wait for 1 ns;
    check_equal(dataOut, x"AA", "Lectura despu¨¦s de escribir AA: debe ser AA");
    check_equal(empty,   '1', "Despu¨¦s de leer: empty debe ser 1");
    check_equal(num_int, 0, "Despu¨¦s de leer: numData debe ser 0");

    -----------------------------------------------------------------
    -- Llenar la FIFO hasta el tope
    report "Llenando FIFO...";
    for i in 1 to DEPTH loop
      dataIn <= std_logic_vector(to_unsigned(i, WL));
      wrE    <= '1';
      wait until rising_edge(clk);
      wrE    <= '0';
      wait for 1 ns;
      num_int := to_integer(unsigned(numData));
      check_equal(num_int, i, "Despu¨¦s de escribir " & integer'image(i) & " datos: numData debe ser " & integer'image(i));
    end loop;

    -- Debe estar llena
    check_equal(full, '1', "Despu¨¦s de llenar: full debe ser 1");
    check_equal(empty, '0', "Despu¨¦s de llenar: empty debe ser 0");

    -- Intentar escribir otro dato (debe ignorarse)
    dataIn <= x"FF";
    wrE    <= '1';
    wait until rising_edge(clk);
    wrE    <= '0';
    wait for 1 ns;
    check_equal(full, '1', "Despu¨¦s de intentar escribir con full=1: full sigue siendo 1");
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, DEPTH, "Despu¨¦s de intentar escribir con full: numData debe seguir siendo DEPTH");

    -- Vaciar la FIFO leyendo todos los datos
    report "Vaciando FIFO...";
    for i in 1 to DEPTH loop
      rdE <= '1';
      wait until rising_edge(clk);
      rdE <= '0';
      wait for 1 ns;
      num_int := to_integer(unsigned(numData));
      check_equal(num_int, DEPTH - i, "Despu¨¦s de leer " & integer'image(i) & " datos: numData debe ser " & integer'image(DEPTH - i));
      -- Verificar que el dato le¨ªdo es correcto (deber¨ªan ser 1,2,3,... en orden)
      check_equal(dataOut, std_logic_vector(to_unsigned(i, WL)), "Dato le¨ªdo debe ser " & integer'image(i));
    end loop;

    check_equal(empty, '1', "Despu¨¦s de vaciar: empty debe ser 1");
    check_equal(full,  '0', "Despu¨¦s de vaciar: full debe ser 0");

    -- Intentar leer con FIFO vac¨ªa (debe ignorarse)
    dataOut <= (others => 'Z');  -- liberar para observar
    wait for 1 ns;
    rdE <= '1';
    wait until rising_edge(clk);
    rdE <= '0';
    wait for 1 ns;
    check_equal(empty, '1', "Despu¨¦s de intentar leer con empty=1: empty sigue siendo 1");
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, 0, "Despu¨¦s de intentar leer con empty: numData sigue siendo 0");
    -- Nota: dataOut puede contener el ¨²ltimo valor le¨ªdo o basura, no verificamos.

    -----------------------------------------------------------------
    -- Prueba de escritura y lectura simult¨¢nea
    report "Prueba de escritura+lectura simult¨¢nea...";
    -- Primero escribir 2 datos
    dataIn <= x"11";
    wrE    <= '1';
    wait until rising_edge(clk);
    dataIn <= x"22";
    wait until rising_edge(clk);
    wrE    <= '0';
    wait for 1 ns;
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, 2, "Despu¨¦s de escribir dos datos: numData=2");

    -- Ahora en el mismo ciclo, escribir y leer
    dataIn <= x"33";
    wrE    <= '1';
    rdE    <= '1';   -- leer¨¢ el dato m¨¢s antiguo (0x11)
    wait until rising_edge(clk);
    wrE    <= '0';
    rdE    <= '0';
    wait for 1 ns;
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, 2, "Despu¨¦s de wr+rd simult¨¢neo: numData debe permanecer en 2");
    check_equal(dataOut, x"11", "Lectura simult¨¢nea debe devolver el dato m¨¢s antiguo (0x11)");

    -- Verificar que el dato escrito (0x33) est¨¢ en la FIFO y el le¨ªdo (0x11) ya no.
    -- Leer el siguiente (deber¨ªa ser 0x22)
    rdE <= '1';
    wait until rising_edge(clk);
    rdE <= '0';
    wait for 1 ns;
    check_equal(dataOut, x"22", "Siguiente lectura debe ser 0x22");
    -- Leer el ¨²ltimo (0x33)
    rdE <= '1';
    wait until rising_edge(clk);
    rdE <= '0';
    wait for 1 ns;
    check_equal(dataOut, x"33", "?ltima lectura debe ser 0x33");
    check_equal(empty, '1', "Despu¨¦s de leer todo, empty debe ser 1");

    -----------------------------------------------------------------
    -- Prueba de wrap-around (llenar y luego leer parcialmente para que los punteros den la vuelta)
    report "Prueba de wrap-around...";
    -- Escribir DEPTH datos (1,2,3,4) para llenar
    for i in 1 to DEPTH loop
      dataIn <= std_logic_vector(to_unsigned(i, WL));
      wrE    <= '1';
      wait until rising_edge(clk);
    end loop;
    wrE <= '0';
    wait for 1 ns;
    check_equal(full, '1', "Wrap: FIFO debe estar llena");

    -- Leer 2 datos (saldr¨¢n 1 y 2)
    rdE <= '1';
    wait until rising_edge(clk);  -- lee 1
    rdE <= '1';
    wait until rising_edge(clk);  -- lee 2
    rdE <= '0';
    wait for 1 ns;
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, DEPTH-2, "Wrap: despu¨¦s de leer 2, numData debe ser 2 (si DEPTH=4, queda 2)");

    -- Escribir 2 datos nuevos (5 y 6) - ahora los punteros de escritura deben dar la vuelta
    dataIn <= x"05";
    wrE    <= '1';
    wait until rising_edge(clk);
    dataIn <= x"06";
    wait until rising_edge(clk);
    wrE    <= '0';
    wait for 1 ns;
    check_equal(full, '1', "Wrap: despu¨¦s de escribir 2, debe quedar llena otra vez");
    num_int := to_integer(unsigned(numData));
    check_equal(num_int, DEPTH, "Wrap: numData debe ser DEPTH");

    -- Leer los 4 datos en orden: deber¨ªan ser 3,4,5,6
    rdE <= '1';
    wait until rising_edge(clk);  -- lee 3
    check_equal(dataOut, x"03", "Wrap: primer dato despu¨¦s de wrap debe ser 3");
    wait until rising_edge(clk);  -- lee 4
    check_equal(dataOut, x"04", "Wrap: segundo dato debe ser 4");
    wait until rising_edge(clk);  -- lee 5
    check_equal(dataOut, x"05", "Wrap: tercer dato debe ser 5");
    wait until rising_edge(clk);  -- lee 6
    check_equal(dataOut, x"06", "Wrap: cuarto dato debe ser 6");
    rdE <= '0';
    wait for 1 ns;
    check_equal(empty, '1', "Wrap: despu¨¦s de leer todo, empty debe ser 1");

    -----------------------------------------------------------------
    -- Fin de la simulaci¨®n
    report "=== Simulaci¨®n completada exitosamente ===";
    wait;
  end process;

end sim;