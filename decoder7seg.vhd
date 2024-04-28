--James Wi
--Lab2 7 Segment decoder

library ieee;
use ieee.std_logic_1164.all;

entity decoder7seg is
    port (
        input : in std_logic_vector(3 downto 0);
        output : out std_logic_vector(6 downto 0));
end decoder7seg; 

architecture decoder of decoder7seg is
    begin

        process(input)
            variable rev: std_logic_vector(6 downto 0);
        begin
            case input is
                when "0000" =>
                rev := "0000001";
                when "0001" =>
                rev := "1001111";
                when "0010" =>
                rev := "0010010";
                when "0011" =>
                rev := "0000110";
                when "0100" =>
                rev := "1001100";
                when "0101" =>
                rev := "0100100";
                when "0110" =>
                rev := "0100000";
                when "0111" =>
                rev := "0001111";
                when "1000" =>
                rev := "0000000";
                when "1001" =>
                rev := "0001100";
                when "1010" =>
                rev := "0001000";
                when "1011" =>
                rev := "1100000";
                when "1100" =>
                rev := "0110001";
                when "1101" =>
                rev := "1000010";
                when "1110" =>
                rev := "0110000";
                when "1111" =>
                rev := "0111000";

                when others => null;
                

            end case;


            
            for i in 0 to 6 loop
                output(i) <= rev(6-i);
            end loop;

        end process;

end decoder;

    