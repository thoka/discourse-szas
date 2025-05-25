# frozen_string_literal: true

namespace :group do
  desc "Entfernt alle Nicht-Eigentümer einer Gruppe"
  task remove_members: :environment do
    group_name = ENV["GROUP"]

    if group_name.blank?
      puts "❌ Bitte gib den Gruppennamen mit GROUP=... an"
      exit 1
    end

    group = Group.find_by(name: group_name)
    unless group
      puts "❌ Gruppe '#{group_name}' nicht gefunden"
      exit 1
    end

    owners = GroupUser.where(group: group, owner: true).pluck(:user_id)
    members = GroupUser.where(group: group).where.not(user_id: owners)

    puts "👉 Entferne #{members.count} Nicht-Eigentümer aus der Gruppe '#{group_name}'..."

    members.find_each do |membership|
      user = membership.user
      puts " - Entferne #{user.username}"
      membership.destroy
    end

    puts "✅ Fertig!"
  end
end
