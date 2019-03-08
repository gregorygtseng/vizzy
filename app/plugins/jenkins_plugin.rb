class JenkinsPlugin < Plugin

  def initialize(unique_id)
    super(unique_id)
  end

  # Jenkins plugin does not require any project settings
  def add_plugin_settings_to_project(project)
    super(project, {
        jenkins_username: {
            value: get_jenkins_username(project),
            display_name: 'Jenkins Username',
            placeholder: "Add jenkins username (e.g., 'jenkins.user')"
        },
        jenkins_password: {
            value: get_jenkins_password(project),
            display_name: 'Jenkins Password',
            placeholder: "Add jenkins password (e.g., 'XXXXXXXX')"
        }
    })
  end

  def get_jenkins_username(project)
    get_plugin_setting_value(project, :jenkins_username)
  end

  def get_jenkins_password(project)
    get_plugin_setting_value(project, :jenkins_password)
  end

  # Update display name and description for Jenkins build when Vizzy build is created
  # Params:
  # - build: build object containing relevant info
  def build_created_hook(build)
    return {dev_build: 'Dev Build, Not Running Jenkins Plugin Hook'} if build.dev_build
    update_display_name_and_description(build)
  end

  private
  def find_or_create_request_service
    @service = @service ||= RequestService.new(@base_jenkins_url, @username, @password)
  end

  # Add comment to jenkins build with link to the visual build
  # Params:
  # - build: build object containing all relevant info
  def update_display_name_and_description(build)
    should_update_description = VizzyConfig.instance.get_config_value(['jenkins', 'update_description'])
    return {success: 'Updating description is turned off in vizzy.yaml'} unless should_update_description

    return {error: "Jenkins Request Info Blank"} if build.title.blank? || build.vizzy_build_url.blank?
    puts "Adding description to Jenkins build with key #{build.title} with build url: #{build.vizzy_build_url }"

    @base_jenkins_url = build.url
    return {error: "Jenkins Build Url Blank"} if @base_jenkins_url.blank?

    @username = get_jenkins_username(build.project)
    return {error: "Jenkins Username Blank"} if @username.blank?

    @password = get_jenkins_password(build.project)
    return {error: "Jenkins Password Blank"} if @password.blank?

    find_or_create_request_service

    data = {
        Submit: "save",
        json: "{ displayName: \"#{build.title}\", description: \"#{build.vizzy_build_url}\" }",
    }
    body = URI.encode_www_form(data)

    post_url = if build.url[-1] == '/'
                 "#{build.url}configSubmit"
               else
                 "#{build.url}/configSubmit"
               end

    # Create Request
    request = Net::HTTP::Post.new(post_url)
    request.add_field "Content-Type", "application/x-www-form-urlencoded"
    request.body = body
    response = @service.make_request(request)
    if response[:error] == "Found"
      # Jenkins returns a 302 found when updating the description
      puts "Successfully updated Jenkins description."
      return {success: "Ok"}
    end
    response
  end
end