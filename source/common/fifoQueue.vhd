-------------------------------------------------------------------
--
--  Fichero:
--    fifo.vhd  1/10/2015
--
--    (c) J.M. Mendias
--    Dise?o Autom¨¢tico de Sistemas
--    Facultad de Inform¨¢tica. Universidad Complutense de Madrid
--
--  Prop¨®sito:
--    Buffer de tipo FIFO
--
--  Notas de dise?o:
--    - Est¨¢ implementada como un banco de registros
--    - Si la FIFO est¨¢ llena, los nuevos datos que se intenten 
--      almacenar se ignoran
--    - Si la FIFO est¨¢ vac¨ªa, las lecturas devuelven valores no
--      validos
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity fifoQueue is
  generic (
    WL    : natural;   -- anchura de la palabra de fifo
    DEPTH : natural    -- numero de palabras en fifo
  );
  port (
    clk     : in  std_logic;   -- reloj del sistema
    rst     : in  std_logic;   -- reset s¨ªncrono del sistema
    wrE     : in  std_logic;   -- se activa durante 1 ciclo para escribir un dato en la fifo
    dataIn  : in  std_logic_vector(WL-1 downto 0);   -- dato a escribir
    rdE     : in  std_logic;   -- se activa durante 1 ciclo para leer un dato de la fifo
    dataOut : out std_logic_vector(WL-1 downto 0);   -- dato a leer
    numData : out std_logic_vector(log2(DEPTH)-1 downto 0);   -- numero de datos almacenados
    full    : out std_logic;   -- indicador de fifo llena
    empty   : out std_logic    -- indicador de fifo vacia
  );
end fifoQueue;

-------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all; -- Necesario para usar el tipo unsigned

architecture syn of fifoQueue is

  type regFileType is array (0 to DEPTH-1) of std_logic_vector(WL-1 downto 0);

  -- Registros
  signal regFile : regFileType := (others => (others => '0'));
  
  -- Cambiamos 'natural' por 'unsigned' para trabajar con tipos basados en std_logic
  signal wrPointer, rdPointer : unsigned(log2(DEPTH)-1 downto 0) := (others => '0');
  signal isFull  : std_logic := '0';
  signal isEmpty : std_logic := '1';
  
  -- A?adimos un contador para facilitar la l¨®gica de elementos almacenados
  signal count   : unsigned(log2(DEPTH) downto 0) := (others => '0'); 

  -- Se?ales  
  signal nextWrPointer, nextRdPointer : unsigned(log2(DEPTH)-1 downto 0);
  signal rdFifo  : std_logic;
  signal wrFifo  : std_logic;
  
begin

  registerFile:
  process (clk, rdPointer, regFile)
  begin
    -- Convertimos el unsigned a integer solo para direccionar el array
    dataOut <= regFile(to_integer(rdPointer)); 
    if rising_edge(clk) then
      if wrFifo='1' then
        regFile(to_integer(wrPointer)) <= dataIn;
      end if;
    end if;
  end process;
 
  -- L¨®gica de control para escritura y lectura
  wrFifo <= wrE and not isFull;
  rdFifo <= rdE and not isEmpty;
  
  -- Incremento circular de los punteros
  nextWrPointer <= (others => '0') when wrPointer = to_unsigned(DEPTH-1, wrPointer'length) else wrPointer + 1;
  nextRdPointer <= (others => '0') when rdPointer = to_unsigned(DEPTH-1, rdPointer'length) else rdPointer + 1;
    
  fsmd:
  process (clk) 
  begin     
    if rising_edge(clk) then
      if rst='1' then
        wrPointer <= (others => '0');
        rdPointer <= (others => '0');
        isFull    <= '0';
        isEmpty   <= '1';
        count     <= (others => '0');
      else
        if wrFifo='1' then
          wrPointer <= nextWrPointer;
          -- Si solo se escribe y no se lee, aumenta la cuenta
          if rdFifo='0' then
            count <= count + 1;
            isEmpty <= '0';
            if count = to_unsigned(DEPTH-1, count'length) then
              isFull <= '1';
            end if;
          end if;
        end if;
        
        if rdFifo='1' then
          rdPointer <= nextRdPointer;
          -- Si solo se lee y no se escribe, disminuye la cuenta
          if wrFifo='0' then
            count <= count - 1;
            isFull <= '0';
            if count = to_unsigned(1, count'length) then
              isEmpty <= '1';
            end if;
          end if;
        end if;
        
        -- Nota: Si wrFifo='1' y rdFifo='1' simult¨¢neamente, ambos punteros
        -- se actualizan, pero "count", "isFull" e "isEmpty" se mantienen igual.
      end if;
    end if;
  end process;
 
  full    <= isFull;
  empty   <= isEmpty;
  -- Truncamos el contador al tama?o especificado por el puerto y lo convertimos a std_logic_vector
  numData <= std_logic_vector(count(log2(DEPTH)-1 downto 0));
 
end syn;