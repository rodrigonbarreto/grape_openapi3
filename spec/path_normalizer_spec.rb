# frozen_string_literal: true

RSpec.describe GrapeOpenapi3::PathNormalizer do
  def normalize(path) = described_class.call(path)

  it { expect(normalize("/v2/lessons(.:format)"))        .to eq("/v2/lessons") }
  it { expect(normalize("/v2/lessons/:id(.:format)"))    .to eq("/v2/lessons/{id}") }
  it { expect(normalize("/v2/users/:user_id/posts/:id")) .to eq("/v2/users/{user_id}/posts/{id}") }
  it { expect(normalize("/v2/users/"))                   .to eq("/v2/users") }
  it { expect(normalize("v2/users"))                     .to eq("/v2/users") }
  it { expect(normalize(""))                             .to eq("/") }
  it { expect(normalize("/v2/bulk_lessons/:id/reopen"))  .to eq("/v2/bulk_lessons/{id}/reopen") }
end
