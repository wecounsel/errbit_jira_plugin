require 'jira'

module ErrbitJiraPlugin
  class IssueTracker < ErrbitPlugin::IssueTracker

    attr_accessor :client

    LABEL = 'jira'

    NOTE = 'Please configure Jira by entering your <strong>username</strong>, <strong>password</strong> and <strong>Jira install url</strong>.'

    FIELDS = {
      :username => {
        :placeholder => "Your username"
      },
      :password => {
        :placeholder => "Your password"
      },
      :site => {
        :placeholder => "URL of your Jira install"
      },
      :context_path => {
        :placeholder => "Context Path if any"
      },
      :project_id => {
        :placeholder => "Your project id to track issues"
      }
    }

    def self.label
      LABEL
    end

    def self.note
      NOTE
    end

    def self.fields
      FIELDS
    end

    def self.body_template
      @body_template ||= ERB.new(File.read(
        File.join(
          ErrbitJiraPlugin.root, 'views', 'jira_issues_body.txt.erb'
        )
      ))
    end

    def configured?
      project_id
    end

    def project_id
      @attributes['options']['project_id']
    end

    def errors
      errors = []
      if self.class.fields.detect {|f| params[f[0]].blank?}
        errors << [:base, 'You must specify your Jira username and password.']
      end
      errors
    end

    def check_params
      if @params['username']
        {}
      else
        { :username => 'Username must be present' }
      end
    end

    def comments_allowed?
      false
    end

    def jira_client
      @client ||= JIRA::Client.new({:username => params['username'], :password => params['password'], :site => params['site'], :auth_type => :basic, :context_path => params['context_path']})
    end

    def create_issue(problem, reported_by = nil)
      begin
        issue_params = {
          :title => "[#{ problem.environment }][#{ problem.where }] #{problem.message.to_s.truncate(100)}",
          :content => self.class.body_template.result(binding).unpack('C*').pack('U*'),
          :kind => 'bug',
          :priority => 'major'
        }
        project = jira_client.Project.find(project_id)
        issue = jira_client.Issue.build
        issue.save({"fields"=>{"summary"=>issue_params, "project"=>{"id"=>project_id},"issuetype"=>{"id"=>"3"}}})
        
        problem.update_attributes(
          :issue_link => jira_url(issue),
          :issue_type => 'Bug'
        )

      rescue JIRA::HTTPError
        raise ErrbitJiraPlugin::IssueError, "Could not create an issue with Jira.  Please check your credentials."
      end
    end

    def jira_url(issue)
      url = params['site'] << '/' unless params['site'].ends_with?('/')
      "#{url}browse/#{issue.key}"
    end

    def url
      "https://www.atlassian.com/software"
    end
  end
end
