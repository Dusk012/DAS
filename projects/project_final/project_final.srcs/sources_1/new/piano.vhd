---------------------------------------------------------------------
-- lab4_piano_vga_fullscreen.vhd
-- Piano con visualizaci¨®n VGA a pantalla completa y BRAM para los niveles de las barras.
--
-- Funcionalidad:
--   - Recibe c¨®digos de teclado PS/2 y reproduce notas musicales (Do..Do agudo).
--   - Cada tecla musical se asocia a una barra vertical en la pantalla VGA.
--   - Las barras "se llenan" mientras la tecla est¨¢ pulsada (nivel 0..120) y 
--     decrecen al soltarla, con una frecuencia de actualizaci¨®n de 5 ms.
--   - El color de cada barra se obtiene de una ROM y se hace m¨¢s brillante 
--     o m¨¢s oscuro seg¨²n la posici¨®n de la l¨ªnea de barrido VGA.
--   - Los scancodes se muestran en los displays de 7 segmentos.
--
-- Caracter¨ªsticas del dise?o:
--   - activeKey = 13 para teclas no musicales (fuera de rango).
--   - La BRAM solo se escribe si activeKey < NUM_KEYS (0..12).
--   - La m¨¢quina de estados original del laboratorio 4 no se modifica.
--   - Se utiliza un ARRAY para almacenar los niveles y un bucle for para actualizarlos.
--   - La l¨®gica est¨¢ completamente comentada para facilitar su comprensi¨®n.
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;   -- Contiene los componentes synchronizer, ps2receiver, vgaRefresher, segsBankRefresher, etc.

entity lab4_piano_vga_fullscreen is
  port (
    clk     : in  std_logic;      -- Reloj principal (100 MHz)
    rst     : in  std_logic;      -- Reset as¨ªncrono (activo alto)
    ps2Clk  : in  std_logic;      -- Reloj del bus PS/2
    ps2Data : in  std_logic;      -- Datos del bus PS/2
    speaker : out std_logic;      -- Salida de audio (onda cuadrada)
    hSync   : out std_logic;      -- Sincronismo horizontal VGA
    vSync   : out std_logic;      -- Sincronismo vertical VGA
    RGB     : out std_logic_vector(11 downto 0); -- Color VGA (R[11:8], G[7:4], B[3:0])
    an_n    : out std_logic_vector(3 downto 0);  -- ?nodos de los displays de 7 segmentos
    segs_n  : out std_logic_vector(7 downto 0)   -- Segmentos de los displays (catodo com¨²n)
  );
end lab4_piano_vga_fullscreen;

architecture syn of lab4_piano_vga_fullscreen is

  -- =========================================================================
  -- CONSTANTES Y PAR?METROS
  -- =========================================================================
  constant FREQ_KHZ      : integer := 100_000;          -- Frecuencia del reloj en kHz
  constant FREQ_HZ       : integer := FREQ_KHZ * 1000;  -- Frecuencia en Hz (100 MHz)
  constant VGA_DIV       : integer := 4;                -- Divisor de reloj para VGA (100 MHz / 4 = 25 MHz)
  constant SCREEN_W      : integer := 640;              -- Ancho de la pantalla VGA
  constant SCREEN_H      : integer := 480;              -- Alto de la pantalla VGA
  constant NUM_KEYS      : integer := 13;               -- N¨²mero de teclas musicales (0..12)
  constant UPDATE_MS     : integer := 5;                -- Periodo de actualizaci¨®n de niveles en milisegundos
  constant UPDATE_CYCLES: integer := ms2cycles(FREQ_KHZ, UPDATE_MS); -- Ciclos de reloj para 5 ms
  constant MAX_LEVEL     : integer := 120;              -- Nivel m¨¢ximo (barra completamente llena)

  -- =========================================================================
  -- SE?ALES INTERNAS DEL PIANO (sin enmascarar)
  -- =========================================================================
  signal rstSync        : std_logic;                      -- Reset sincronizado
  signal dataRdy        : std_logic;                      -- '1' cuando hay un nuevo dato PS/2
  signal ldCode         : std_logic;                      -- Se?al para cargar el scancode
  signal halfPeriod     : integer := 0;                   -- Semi-periodo de la nota musical
  signal data_int       : std_logic_vector(7 downto 0);   -- Dato recibido del PS/2 (8 bits)
  signal data           : std_logic_vector(7 downto 8);   -- Alias (posiblemente un error de tipeo, deber¨ªa ser 7 downto 0)
  signal soundEnable    : std_logic;                      -- Habilita la salida del altavoz
  signal count          : integer := 0;                   -- Contador para generar la onda cuadrada
  signal speakerTFF     : std_logic := '0';               -- Flip-flop T para el altavoz
  signal code           : std_logic_vector(7 downto 0) := (others => '0'); -- Scancode almacenado

  -- =========================================================================
  -- M?QUINA DE ESTADOS (ORIGINAL DEL LABORATORIO 4)
  -- =========================================================================
  type states is (S0, S1, S2, S3);
  signal current_state, next_state : states;

  -- =========================================================================
  -- VGA Y PIPELINE
  -- =========================================================================
  signal vga_line       : std_logic_vector(9 downto 0);   -- L¨ªnea actual de barrido VGA
  signal vga_pixel      : std_logic_vector(9 downto 0);   -- Pixel actual en la l¨ªnea
  signal hSync_int      : std_logic;                      -- Sincronismo horizontal interno
  signal vSync_int      : std_logic;                      -- Sincronismo vertical interno
  signal hSync_reg      : std_logic;                      -- Registro para alinear timings
  signal vSync_reg      : std_logic;                      -- Registro para alinear timings
  signal vga_line_d1    : std_logic_vector(9 downto 0);   -- L¨ªnea registrada (pipeline)
  signal color_out      : std_logic_vector(11 downto 0);  -- Color generado para el p¨ªxel actual

  -- =========================================================================
  -- ?NDICE DE TECLA Y GESTI?N DE NIVELES
  -- =========================================================================
  signal activeKey      : integer range 0 to NUM_KEYS := 13; -- Tecla actual (13 = ninguna/sin sonido)
  signal fill_level_local_vec : std_logic_vector(12 downto 0) := (others => '0'); -- Vector de m¨¢scara: cada bit indica si la tecla est¨¢ pulsada
  signal update_pulse   : std_logic;                      -- Pulso de 1 ciclo cada 5 ms
  signal write_counter  : integer range 0 to 12 := 0;     -- Contador para volcar los niveles en la BRAM

  -- =========================================================================
  -- ARRAY DE NIVELES (optimizaci¨®n con bucle for)
  -- =========================================================================
  type level_array_t is array (0 to 12) of integer range 0 to MAX_LEVEL;
  signal lvl : level_array_t := (others => 0);            -- Nivel actual de cada barra

  -- =========================================================================
  -- SE?ALES PARA EL DIRECCIONAMIENTO VGA
  -- =========================================================================
  signal seg_calc   : integer range 0 to NUM_KEYS-1 := 0; -- ?ndice de la barra seg¨²n la columna del p¨ªxel
  signal seg_reg    : integer range 0 to NUM_KEYS-1 := 0; -- Registro del ¨ªndice para lectura s¨ªncrona
  signal pixel_x    : integer := 0;                       -- Posici¨®n horizontal del p¨ªxel actual
  signal upd_cnt    : integer := 0;                       -- Contador para generar update_pulse

  -- =========================================================================
  -- C?LCULO DE COLOR
  -- =========================================================================
  signal y_int      : integer := 0;                       -- L¨ªnea VGA como entero
  signal level_int  : integer := 0;                       -- Nivel le¨ªdo de la BRAM
  signal lit_min_y  : integer := 0;                       -- L¨ªnea a partir de la cual la barra se ilumina

  -- =========================================================================
  -- SE?ALES DE INTERFAZ PARA LA BRAM Y LA ROM DE COLORES
  -- =========================================================================
  signal fill_level_we    : std_logic_vector(0 downto 0); -- Write enable de la BRAM
  signal fill_level_addr_w: std_logic_vector(3 downto 0); -- Direcci¨®n de escritura (4 bits -> 16 posiciones)
  signal fill_level_din   : std_logic_vector(6 downto 0); -- Dato a escribir (7 bits, nivel 0..120)
  signal fill_level_addr_r: std_logic_vector(3 downto 0); -- Direcci¨®n de lectura para VGA
  signal fill_level_dout  : std_logic_vector(6 downto 0); -- Dato le¨ªdo de la BRAM
  signal color_rom_addr   : std_logic_vector(3 downto 0); -- Direcci¨®n de la ROM de colores
  signal color_rom_data   : std_logic_vector(11 downto 0);-- Color de la barra seleccionada

  -- =========================================================================
  -- COMPONENTES
  -- =========================================================================
  component fill_level_ram
    port (
      clka  : in std_logic;
      wea   : in std_logic_vector(0 downto 0);
      addra : in std_logic_vector(3 downto 0);
      dina  : in std_logic_vector(6 downto 0);
      clkb  : in std_logic;
      addrb : in std_logic_vector(3 downto 0);
      doutb : out std_logic_vector(6 downto 0)
    );
  end component;

  component color_rom
    port (
      clka  : in std_logic;
      addra : in std_logic_vector(3 downto 0);
      douta : out std_logic_vector(11 downto 0)
    );
  end component;

begin

  --------------------------------------------------------------------
  -- 1. RESET SINCRONIZADO Y RECEPCI?N PS/2
  --------------------------------------------------------------------
  -- El reset externo se sincroniza para evitar metaestabilidad.
  resetSync : synchronizer
    generic map (STAGES => 2, XPOL => '0')
    port map (clk => clk, x => rst, xSync => rstSync);

  -- Receptor de teclado PS/2. Entrega dataRdy y el byte recibido.
  ps2 : ps2receiver
    port map (clk => clk, rst => rstSync, dataRdy => dataRdy,
              data => data_int, ps2Clk => ps2Clk, ps2Data => ps2Data);
              
  -- Asignaci¨®n del dato (nota: data est¨¢ declarado con rango extra?o, 
  -- se utiliza data_int para el resto de la l¨®gica).
  data <= data_int;

  -- Registro que almacena el scancode cuando la FSM lo ordena.
  codeRegister : process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        code <= (others => '0');
      elsif ldCode = '1' then
        code <= data;
      end if;
    end if;
  end process;

  -- Tabla de semiper¨ªodos: asigna a cada scancode su correspondiente semi-periodo
  -- para generar la frecuencia de la nota (F = FREQ_HZ / (2*halfPeriod)).
  halfPeriodROM : with code select
    halfPeriod <=
      FREQ_HZ/(2*262) when X"1c",  -- A = Do
      FREQ_HZ/(2*277) when X"1d",  -- W = Do#
      FREQ_HZ/(2*294) when X"1b",  -- S = Re
      FREQ_HZ/(2*311) when X"24",  -- E = Re#
      FREQ_HZ/(2*330) when X"23",  -- D = Mi
      FREQ_HZ/(2*349) when X"2b",  -- F = Fa
      FREQ_HZ/(2*370) when X"2c",  -- T = Fa#
      FREQ_HZ/(2*392) when X"34",  -- G = Sol
      FREQ_HZ/(2*415) when X"35",  -- Y = Sol#
      FREQ_HZ/(2*440) when X"33",  -- H = La
      FREQ_HZ/(2*466) when X"3c",  -- U = La#
      FREQ_HZ/(2*494) when X"3b",  -- J = Si
      FREQ_HZ/(2*523) when X"42",  -- K = Do agudo
      0 when others;               -- Cualquier otro scancode -> sin sonido

  -- Generador de la onda cuadrada para el altavoz.
  -- El contador count se carga con halfPeriod y decrece; al llegar a 0 
  -- se invierte speakerTFF y se recarga el contador.
  cycleCounter : process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        count <= 0;
        speakerTFF <= '0';
      else
        if soundEnable = '1' and halfPeriod /= 0 then
          if count = 0 then
            count <= halfPeriod - 1;
            speakerTFF <= not speakerTFF;
          else
            count <= count - 1;
          end if;
        else
          count <= 0;
          speakerTFF <= '0';
        end if;
      end if;
    end if;
  end process;

  speaker <= speakerTFF when soundEnable = '1' else '0';

  --------------------------------------------------------------------
  -- 2. M?QUINA DE ESTADOS ORIGINAL DEL LABORATORIO 4
  --------------------------------------------------------------------
  -- La FSM interpreta los mensajes del teclado PS/2:
  --   S0: espera comando.
  --   S1: tecla pulsada y reproduciendo nota.
  --   S2: espera el c¨®digo de liberaci¨®n (break) de la tecla actual.
  --   S3: descarta el byte tras el c¨®digo de break.
  fsm_comb : process (current_state, dataRdy, data, code)
  begin
    ldCode <= '0';
    soundEnable <= '0';
    next_state <= current_state;
    case current_state is
      when S0 =>
        if dataRdy = '1' then
          if data = X"AA" then          -- C¨®digo de auto-test (ignorado)
            next_state <= S0;
          elsif data = X"F0" then       -- C¨®digo de break
            next_state <= S3;
          elsif data /= X"F0" then      -- C¨®digo de make (tecla pulsada)
            next_state <= S1;
            ldCode <= '1';              -- Cargar el scancode
          end if;
        end if;
      when S1 =>
        soundEnable <= '1';             -- Sonido activo mientras la tecla est¨¦ pulsada
        if dataRdy = '1' then
          if data = X"F0" then          -- Llega el c¨®digo de break de la tecla actual
            next_state <= S2;
          end if;
        end if;
      when S2 =>
        soundEnable <= '1';             -- Sigue sonando hasta que llegue el scancode exacto
        if dataRdy = '1' then
          if data = code then           -- Confirma que es la misma tecla
            next_state <= S0;
          else
            next_state <= S1;           -- Si no coincide, puede ser otra tecla pulsada
          end if;
        end if;
      when S3 =>
        if dataRdy = '1' then
          next_state <= S0;             -- Descarta el byte y vuelve a reposo
        end if;
    end case;
  end process;

  -- Registro de estado s¨ªncrono.
  fsm_seq : process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        current_state <= S0;
      else
        current_state <= next_state;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- 3. GENERACI?N DEL VECTOR DE TECLAS ACTIVAS (m¨¢scara de bits)
  --------------------------------------------------------------------
  -- Convierte la tecla actual en un vector de 13 bits donde solo 
  -- el bit correspondiente a activeKey est¨¢ a '1', siempre que sea 
  -- una tecla musical (activeKey < 13) y el sonido est¨¦ habilitado.
  process (soundEnable, activeKey)
  begin
    fill_level_local_vec <= (others => '0');
    if soundEnable = '1' and activeKey < NUM_KEYS then
      fill_level_local_vec(activeKey) <= '1';
    end if;
  end process;

  --------------------------------------------------------------------
  -- 4. MAPEO DE SCANCODE A ?NDICE DE TECLA (13 = no musical)
  --------------------------------------------------------------------
  activeKey <= 0 when code = X"1c" else  -- Do
               1 when code = X"1d" else  -- Do#
               2 when code = X"1b" else  -- Re
               3 when code = X"24" else  -- Re#
               4 when code = X"23" else  -- Mi
               5 when code = X"2b" else  -- Fa
               6 when code = X"2c" else  -- Fa#
               7 when code = X"34" else  -- Sol
               8 when code = X"35" else  -- Sol#
               9 when code = X"33" else  -- La
              10 when code = X"3c" else  -- La#
              11 when code = X"3b" else  -- Si
              12 when code = X"42" else  -- Do agudo
              13;                         -- cualquier otro scancode

  --------------------------------------------------------------------
  -- 5. GENERADOR DE PULSO DE ACTUALIZACI?N (cada 5 ms)
  --------------------------------------------------------------------
  -- Un contador libre genera un pulso de un ciclo cada UPDATE_MS 
  -- milisegundos. Este pulso se usa para actualizar los niveles de las barras.
  process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        upd_cnt <= 0;
        update_pulse <= '0';
      else
        if upd_cnt = UPDATE_CYCLES - 1 then
          upd_cnt <= 0;
          update_pulse <= '1';
        else
          upd_cnt <= upd_cnt + 1;
          update_pulse <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- 6. L?GICA DE ACTUALIZACI?N DE NIVELES MEDIANTE ARRAY
  --------------------------------------------------------------------
  -- En cada pulso update_pulse, un bucle for recorre las 13 teclas y 
  -- actualiza sus niveles en paralelo (en un solo ciclo de reloj):
  --   - Si la tecla est¨¢ pulsada y el nivel < MAX_LEVEL, incrementa.
  --   - Si la tecla no est¨¢ pulsada y el nivel > 0, decrementa.
  process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        lvl <= (others => 0);
      elsif update_pulse = '1' then
        for i in 0 to 12 loop
          if fill_level_local_vec(i) = '1' then
            if lvl(i) < MAX_LEVEL then 
              lvl(i) <= lvl(i) + 1; 
            end if;
          else
            if lvl(i) > 0 then 
              lvl(i) <= lvl(i) - 1; 
            end if;
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- Contador c¨ªclico 0..12 que se incrementa en cada ciclo de reloj.
  -- Se utiliza para ir volcando los valores del array lvl hacia la BRAM 
  -- de forma continua, un ¨ªndice por ciclo.
  process (clk)
  begin
    if rising_edge(clk) then
      if rstSync = '1' then
        write_counter <= 0;
      else
        if write_counter = 12 then
          write_counter <= 0;
        else
          write_counter <= write_counter + 1;
        end if;
      end if;
    end if;
  end process;

  -- Interfaz de escritura de la BRAM.
  -- Se escribe permanentemente (we = '1'), con la direcci¨®n y el dato 
  -- correspondientes al ¨ªndice actual del contador.
  fill_level_we(0)  <= '1';
  fill_level_addr_w <= std_logic_vector(to_unsigned(write_counter, 4));
  fill_level_din    <= std_logic_vector(to_unsigned(lvl(write_counter), 7));

  --------------------------------------------------------------------
  -- 7. DIRECCIONAMIENTO DE LECTURA PARA VGA
  --------------------------------------------------------------------
  -- Se calcula el ¨ªndice de la barra en funci¨®n de la columna del p¨ªxel actual.
  -- La pantalla de 640 p¨ªxeles se divide entre 13 barras, cada una de ancho ~49 p¨ªxeles.
  -- La aproximaci¨®n (pixel_x * 21) / 1024 evita el uso de una divisi¨®n entera costosa.
  pixel_x <= to_integer(unsigned(vga_pixel));
  seg_calc <= (pixel_x * 21) / 1024;   -- Equivale a pixel_x / 48.76...
  seg_reg <= seg_calc when seg_calc < NUM_KEYS else NUM_KEYS - 1;

  -- Registra las direcciones para sincronizar las memorias con el pipeline VGA.
  process (clk)
  begin
    if rising_edge(clk) then
      fill_level_addr_r <= std_logic_vector(to_unsigned(seg_reg, 4));
      color_rom_addr    <= std_logic_vector(to_unsigned(seg_reg, 4));
    end if;
  end process;

  --------------------------------------------------------------------
  -- 8. PIPELINE DE SINCRONISMOS VGA
  --------------------------------------------------------------------
  -- Se registran las se?ales de sincronismo y la l¨ªnea para alinear 
  -- los datos de color con la salida del refresher.
  process (clk)
  begin
    if rising_edge(clk) then
      hSync_reg   <= hSync_int;
      vSync_reg   <= vSync_int;
      vga_line_d1 <= vga_line;
    end if;
  end process;

  hSync <= hSync_reg;
  vSync <= vSync_reg;

  --------------------------------------------------------------------
  -- 9. INSTANCIAS DE BRAM Y ROM DE COLORES
  --------------------------------------------------------------------
  -- BRAM que almacena los niveles de las 13 barras.
  bram_fill : fill_level_ram
    port map (
      clka  => clk, wea => fill_level_we, addra => fill_level_addr_w, dina => fill_level_din,
      clkb  => clk, addrb => fill_level_addr_r, doutb => fill_level_dout
    );

  -- ROM que contiene los colores base de cada barra (12 bits RGB).
  rom_colors : color_rom
    port map (
      clka  => clk, addra => color_rom_addr, douta => color_rom_data
    );

  --------------------------------------------------------------------
  -- 10. REFRESHER VGA
  --------------------------------------------------------------------
  -- Genera las se?ales de sincronismo y las coordenadas (l¨ªnea, p¨ªxel) 
  -- para la pantalla de 640x480. La salida RGB se toma de color_out.
  vga_inst : vgaRefresher
    generic map (FREQ_DIV => VGA_DIV)
    port map (
      clk   => clk,
      line  => vga_line,
      pixel => vga_pixel,
      R     => color_out(11 downto 8),
      G     => color_out(7 downto 4),
      B     => color_out(3 downto 0),
      hSync => hSync_int,
      vSync => vSync_int,
      RGB   => RGB
    );

  --------------------------------------------------------------------
  -- 11. GENERACI?N DEL COLOR PARA CADA P?XEL
  --------------------------------------------------------------------
  -- El color de cada barra se modifica seg¨²n la l¨ªnea de barrido:
  --   - Si la l¨ªnea est¨¢ por debajo de lit_min_y, la barra se pinta con su color base (brillante).
  --   - Si est¨¢ por encima, se pinta con una versi¨®n oscurecida (se aplica AND con X"888").
  --   - Si el nivel es 0, toda la barra se pinta de blanco (fondo).
  y_int     <= to_integer(unsigned(vga_line_d1));
  level_int <= to_integer(unsigned(fill_level_dout));
  lit_min_y <= SCREEN_H - (level_int * 4);   -- Por cada unidad de nivel se iluminan 4 l¨ªneas m¨¢s

  process (y_int, level_int, lit_min_y, color_rom_data)
  begin
    if level_int > 0 then
      if y_int >= lit_min_y then
        color_out <= color_rom_data or X"888";   -- Mezcla con blanco (m¨¢s brillante)
      else
        color_out <= color_rom_data and X"888";  -- Oscurece (reduce intensidad)
      end if;
    else
      color_out <= X"FFF";                        -- Blanco (barra vac¨ªa)
    end if;
  end process;

  --------------------------------------------------------------------
  -- 12. INTERFAZ DE DISPLAYS DE 7 SEGMENTOS
  --------------------------------------------------------------------
  -- Muestra el scancode actual en los displays.
  displayInterface : segsBankRefresher
    generic map (FREQ_KHZ => FREQ_KHZ, SIZE => 4)
    port map (
      clk    => clk,
      ens    => "0110",                          -- Habilita los displays 1 y 2 (scancode de 8 bits)
      bins   => "0000" & code & "0000",          -- El scancode se coloca en los 8 bits centrales
      dps    => "0000",                          -- Puntos decimales apagados
      an_n   => an_n,
      segs_n => segs_n
    );

end syn;