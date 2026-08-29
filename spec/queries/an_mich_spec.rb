# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Kategorie 'An mich'" do
  fab!(:user) { Fabricate(:user) }
  fab!(:outsider) { Fabricate(:user) }
  fab!(:author) { Fabricate(:user) }

  before do
    @category = SzasSharedTopics.ensure_an_mich_category
  end

  fab!(:direct_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
    )
  end

  fab!(:foreign_pm) do
    Fabricate(
      :private_message_topic,
      user: author,
      topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: outsider)],
    )
  end

  def list_ids(list_user)
    TopicQuery.new(list_user, category: @category.id).list_latest.topics.map(&:id)
  end

  it "existiert genau einmal und sortiert mit position -1 nach vorn" do
    again = SzasSharedTopics.ensure_an_mich_category

    expect(again.id).to eq(@category.id)
    expect(@category.reload.position).to eq(-1)
  end

  it "zeigt der Person ihre direkt adressierten PMs" do
    expect(list_ids(user)).to contain_exactly(direct_pm.id)
  end

  it "zeigt fremde PMs nicht" do
    # outsider sieht seine eigene PM - aber nicht die von user
    expect(list_ids(outsider)).to contain_exactly(foreign_pm.id)
  end

  it "bleibt für anonyme Zugriffe leer" do
    expect(list_ids(nil)).to eq([])
  end

  it "verweigert das Anlegen echter Topics in der Kategorie" do
    guardian = Guardian.new(user)

    expect(guardian.can_create_topic?(@category.id)).to eq(false)
  end

  it "listet die Kategorie in der Übersicht vor allen anderen" do
    Fabricate(:category, position: 5)

    first = Category.order(:position, :id).first
    expect(first.slug).to eq("an-mich")
  end
end
