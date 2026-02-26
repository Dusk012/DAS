-------------------------------------------------------------------
--
--  Fichero:
--    debouncer.vhd  (modificado sin variables)
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Elimina los rebotes de una línea binaria (sin variables)
--
--  Notas de diseño:
--    Orientado a FPGA Xilinx 7 series: reset síncrono, con señales
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity debouncer is
  generic(
    FREQ_KHZ  : natural;    -- frecuencia de operacion en KHz
    BOUNCE_MS : natural;    -- tiempo de rebote en ms
    XPOL      : std_logic   -- polaridad (valor en reposo) de la señal
  );
  port (
    clk  : in  std_logic;   -- reloj del sistema
    rst  : in  std_logic;   -- reset síncrono
    x    : in  std_logic;   -- entrada con rebotes
    xDeb : out std_logic    -- salida sin rebotes
  );
end debouncer;

-------------------------------------------------------------------

architecture syn of debouncer is
  constant CYCLES : natural := ms2cycles(FREQ_KHZ, BOUNCE_MS);
  type states is (waitingKeyDown, keyDownDebouncing, waitingKeyUp, KeyUpDebouncing);
  signal state, next_state : states;
  signal count, next_count : natural range 0 to CYCLES-1;
  signal timerEnd : std_logic;
begin
  -- Indicador de fin de temporización
  timerEnd <= '1' when count = 0 else '0';

  -- Registros de estado y contador
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= waitingKeyDown;
        count <= 0;
      else
        state <= next_state;
        count <= next_count;
      end if;
    end if;
  end process;

  -- Lógica combinacional de la máquina de estados y contador
  process (state, count, x, timerEnd)
  begin
    -- Valores por defecto
    xDeb <= XPOL;
    next_state <= state;
    next_count <= count;

    case state is
      when waitingKeyDown =>
        if x /= XPOL then
          next_count <= CYCLES - 1;
          next_state <= keyDownDebouncing;
        end if;

      when keyDownDebouncing =>
        xDeb <= not XPOL;
        if timerEnd = '1' then
          next_state <= waitingKeyUp;
          next_count <= 0;
        else
          next_count <= count - 1;
        end if;

      when waitingKeyUp =>
        xDeb <= not XPOL;
        if x = XPOL then
          next_count <= CYCLES - 1;
          next_state <= KeyUpDebouncing;
        end if;

      when KeyUpDebouncing =>
        if timerEnd = '1' then
          next_state <= waitingKeyDown;
          next_count <= 0;
        else
          next_count <= count - 1;
        end if;
    end case;
  end process;
end syn;