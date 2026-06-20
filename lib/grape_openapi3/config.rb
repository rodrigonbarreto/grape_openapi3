# frozen_string_literal: true

module GrapeOpenapi3
  # Configuration object passed through the document build.
  #
  # schema_name_separator: joins namespace segments when two entities share the
  #   same short name (e.g. V2::Mentors::MenteeResponse vs V2::Kids::MenteeResponse
  #   become "Mentors_MenteeResponse" / "Kids_MenteeResponse"). Default "_".
  Config = Struct.new(
    :info, :servers, :security_schemes, :security, :tags, :schema_name_separator,
    keyword_init: true
  ) do
    def schema_name_separator
      self[:schema_name_separator] || "_"
    end
  end
end