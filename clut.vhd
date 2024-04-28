library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 

entity CLUT is

	port( 	bitin : in std_logic_vector(3 downto 0);
			bitout: out std_logic_vector(11 downto 0));
			
end CLUT;

architecture CLUT_arch of CLUT is

begin

	process(bitin)
    begin
        case bitin is
            when "0000" =>
                bitout <= x"F00";
            when "0001" =>
                bitout <= x"F70";
            when "0010" =>
                bitout <= x"FF0";
            when "0011" =>
                bitout <= x"0F0";
            when "0100" =>
                bitout <= x"0FF";
            when "0101" =>
                bitout <= x"00F";
            when "0110" =>
                bitout <= x"70F";
            when "0111" =>
                bitout <= x"F0F";
            when others => 
                bitout <= x"000";
        end case;

    end process;
	
end CLUT_arch;
