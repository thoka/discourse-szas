# frozen_string_literal: true

require "rails_helper"

RSpec.describe "private Themen in der Kategorieliste" do
  fab!(:category) { Fabricate(:category) }
  fab!(:user) { Fabricate(:user) }
  fab!(:outsider) { Fabricate(:user) }

  fab!(:shared_pm) do
    pm =
      Fabricate(
        :private_message_topic,
        user: Fabricate(:user),
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      )
    pm.custom_fields[SzasSharedTopics::CATEGORY_FIELD] = category.id
    pm.save_custom_fields
    pm
  end

  def list_for(list_user)
    TopicQuery.new(list_user, category: category.id).list_latest.topics.map(&:id)
  end

  it "zeigt das zugeordnete PM ihren Teilnehmenden in der Kategorieliste" do
    expect(list_for(user)).to contain_exactly(shared_pm.id)
  end

  it "zeigt die Kategorie zusätzlich ihre regulären Topics" do
    regular = Fabricate(:topic, category: category, user: user)

    expect(list_for(user)).to contain_exactly(shared_pm.id, regular.id)
  end

  it "zeigt das PM Nicht-Teilnehmenden nicht" do
    expect(list_for(outsider)).to eq([])
  end

  it "hält das PM aus anderen Kategorielisten heraus" do
    other = Fabricate(:category)

    expect(TopicQuery.new(user, category: other.id).list_latest.topics.map(&:id)).to eq([])
  end

  it "listet nur PMs, die dem Bereich zugeordnet sind" do
    unmapped =
      Fabricate(
        :private_message_topic,
        user: Fabricate(:user),
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      )

    expect(list_for(user)).to contain_exactly(shared_pm.id)
  end
end
