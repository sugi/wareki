# frozen_string_literal: true

require 'ya_kansuji'
require 'wareki/utils'

module Wareki
  # [DEPRECATED] Utilities of kansuji/integer converter.
  module Kansuji
    module_function

    # DEPRECATED
    def kan_to_i(str)
      warn '[DEPRECATED] Wareki::Kansuji#kan_to_i: Please use ya_kansuji gem to handle kansuji'
      Utils.k2i str
    end

    # DEPRECATED
    def i_to_kan(num)
      warn '[DEPRECATED] Wareki::Kansuji#i_to_kan: Please use ya_kansuji gem to handle kasuji'
      YaKansuji.to_kan num
    end

    def i_to_zen(num)
      Utils.i2z num
    end

    class << self
      alias i2k i_to_kan
      alias k2i kan_to_i
      alias i2z i_to_zen
    end
  end
end
