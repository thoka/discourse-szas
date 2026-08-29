# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nachrichten an mich" do
  fab!(:user) { Fabricate(:user) }
  fab!(:outsider) { Fabricate(:user) }

  fab!(:group) { Fabricate(:group) }
  fab!(:other_group) { Fabricate(:group) }
  before do
    group.add(user)
    other_group.add(outsider)
  end

  fab!(:author) { Fabricate(:user) }

  fab!(:direct_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
    )
  end

  fab!(:group_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
    )
  end

  fab!(:both_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
    )
  end

  fab!(:foreign_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: outsider)],
    )
  end

  def listed_ids
    response.parsed_body.map { |topic| topic["id"] }
  end

  it "listet für angemeldete Nutzer alle ihre PMs - direkt wie über Gruppen" do
    sign_in(user)

    get "/szas/my-messages.json"

    expect(response.status).to eq(200)
    expect(listed_ids).to contain_exactly(direct_pm.id, group_pm.id, both_pm.id)
  end

  it "weist anonyme Zugriffe ab" do
    get "/szas/my-messages.json"

    expect(response.status).to eq(403)
  end

  it "listet PMs anderer nicht, auch wenn sie existieren" do
    sign_in(outsider)

    get "/szas/my-messages.json"

    expect(response.status).to eq(200)
    expect(listed_ids).not_to include(direct_pm.id, group_pm.id, both_pm.id)
  end

  it "zeigt in der Box 'direkt' alle PMs, die an mich adressiert sind - auch solche, die zugleich eine Gruppe bekommen" do
    sign_in(user)

    get "/szas/my-messages.json?box=direct"

    expect(listed_ids).to contain_exactly(direct_pm.id, both_pm.id)
  end

  it "zeigt in einer Gruppenbox die PMs dieser Gruppe" do
    sign_in(user)

    get "/szas/my-messages.json?box=group:#{group.id}"

    expect(listed_ids).to contain_exactly(group_pm.id, both_pm.id)
  end

  it "listet in der Gruppenbox keine PMs fremder Gruppen" do
    sign_in(outsider)

    get "/szas/my-messages.json?box=group:#{group.id}"

    expect(response.status).to eq(404)
  end

  it "zählt die Boxen für die Navigation" do
    sign_in(user)

    get "/szas/my-messages/boxes.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to contain_exactly(
      { "key" => "direct", "name" => "Direkt", "count" => 2 },
      { "key" => "group:#{group.id}", "name" => group.name, "count" => 2 },
    )
  end
end
