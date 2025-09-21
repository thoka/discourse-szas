namespace :szas do
  # Define the rake task
  Rake::Task.define_task "posts:delete_klassenlisten",
                         [:username] => :environment do |t, args|
    username = "Konfigurations-Bot"

    # Find the user
    user = User.find_by(username: username)
    if user.nil?
      puts "Error: User '#{username}' not found"
      exit 1
    end

    puts "Searching for private posts by user '#{username}' containing 'Klassenliste' in title..."

    # Find private messages (topics) created by the user with "Klassenliste" in title
    private_topics =
      Topic
        .joins(:topic_allowed_users)
        .where(user: user)
        .where(archetype: Archetype.private_message)
        .where("title LIKE ?", "Klassenliste LG%")

    if private_topics.empty?
      puts "No private posts found with 'Klassenliste' in title by user '#{username}'"
      exit 0
    end

    puts "Found #{private_topics.count} private topic(s):"
    private_topics.each do |topic|
      puts "  - ID: #{topic.id}, Title: #{topic.title}"
    end

    unless private_topics.empty?
      puts "\nDeleting topics (including all posts)..."
      deleted_count = 0

      private_topics.find_each do |topic|
        begin
          # Use Discourse's TopicDestroyer to delete entire topic with all posts
          TopicDestroyer.new(user, topic).destroy
          puts "  - Deleted topic ID: #{topic.id} - '#{topic.title}'"
          deleted_count += 1
        rescue => e
          puts "  - Error deleting topic ID #{topic.id}: #{e.message}"
        end
      end

      puts "\nSummary:"
      puts "  Total topics deleted: #{deleted_count}"
    end

    puts "\nOperation completed."
  end
end
