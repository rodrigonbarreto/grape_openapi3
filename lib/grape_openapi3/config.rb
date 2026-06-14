# frozen_string_literal: true

module GrapeOpenapi3
  Config = Struct.new(:info, :servers, :security_schemes, :security, :tags, keyword_init: true)
end
