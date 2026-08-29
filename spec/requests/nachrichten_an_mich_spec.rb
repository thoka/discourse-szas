# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nachrichten an mich" do
  fab!(:user) { Fabricate(:user) }
  fab!(:outsider) { Fabricate(:user) }

  fab!(:pm) do
    Fabricate(
      :private_message_topic,
      user: Fabricate(:user),
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
    )
  end

  it "listet für angemeldete Nutzer genau die PMs, an denen sie beteiligt sind" do
    sign_in(user)

    get "/szas/nachrichten-an-mich.json"

    expect(response.status).to eq(200)
    listed = response.parsed_body["topics"].map { |topic| topic["id"] }
    expect(listed).to contain_exactly(pm.id)
  end

  it "endet für anonyme Zugriffe mit 404" do
    get "/szas/nachrichten-an-mich.json"

    expect(response.status).to eq(404)
  end

  it "listet PMs anderer nicht, auch wenn sie existieren" do
    sign_in(outsider)

    get "/szas/nachrichten-an-mich.json"

    listed = response.parsed_body["topics"].map { |topic| topic["id"] }
    expect(listed).not_to include(pm.id)
  end
end
