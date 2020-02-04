require 'jira-ruby'

module ErrbitJiraPlugin
  class IssueTracker < ErrbitPlugin::IssueTracker
    LABEL = 'jira'

    NOTE = 'Please configure Jira by entering the information below.'

    FIELDS = {
      :base_url => {
          :label => 'Jira URL without trailing slash',
          :placeholder => 'https://jira.example.org'
      },
      :context_path => {
          :optional => true,
          :label => 'Context Path',
          :placeholder => "/jira"
      },
      :username => {
          :label => 'Username',
          :placeholder => 'johndoe'
      },
      :password => {
          :label => 'Password',
          :placeholder => 'p@assW0rd'
      },
      :project_id => {
          :label => 'Project Key',
          :placeholder => 'The project Key where the issue will be created'
      },
      :issue_priority => {
          :label => 'Priority',
          :placeholder => 'Normal'
      },
      :issue_type => {
          :label => 'Issue Type',
          :placeholder => 'Bug'
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

    def self.icons
      @icons ||= {
        create: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_create.png')
        ],
        goto: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_goto.png'),
        ],
        inactive: [
          'image/png', ErrbitJiraPlugin.read_static_file('jira_inactive.png'),
        ]
      }
    end

    def self.body_template
      @body_template ||= ERB.new(File.read(
        File.join(
          ErrbitJiraPlugin.root, 'views', 'jira_issues_body.txt.erb'
        )
      ))
    end

    def configured?
      options['project_id'].present?
    end

    def errors
      errors = []
      if self.class.fields.detect {|f| options[f[0]].blank? }
        errors << [:base, 'You must specify all non optional values!']
      end
      errors
    end

    def comments_allowed?
      false
    end

    def create_issue(title, body, user: {})
      begin
        project = jira_client.Project.find(options['project_id'])

        issue_fields =
          {
            "fields" => {
              "summary"     => title[0...50],
              "description" => body,
              "project"     => {"id"   => project.id},
              "issuetype"   => {"id"   => issue_type_for(options['issue_type'])&.id},
              "priority"    => {"name" => options['issue_priority']}
            }
          }

        jira_issue = jira_client.Issue.build

        jira_issue.save(issue_fields)

        jira_url(jira_issue.key)
      rescue JIRA::HTTPError => e
        if e.response&.body
          raise ErrbitJiraPlugin::IssueError, "Could not create an issue with Jira. #{e.response.body}"
        else
          raise ErrbitJiraPlugin::IssueError, "Could not create an issue with Jira.  Please check your credentials."
        end
      end
    end

    def jira_url(project_id)
      "#{options['base_url']}#{context_path}browse/#{project_id}"
    end

    def url
      options['base_url']
    end

    private

    def context_path
      options['context_path'] == '' ? '/' : options['context_path']
    end

    def issue_type_for(type)
      issue_types.select{|t| t.name == type}.first
    end

    def issue_types
      @issue_types ||= jira_client.Issuetype.all
    end

    def jira_client
      jira_options = {
        :username => options['username'],
        :password => options['password'],
        :site => options['base_url'],
        :auth_type => :basic,
        :context_path => context_path
      }

      @jira_client ||= JIRA::Client.new(jira_options)
    end
  end
end
