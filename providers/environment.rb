#
# Cookbook Name:: icinga2
# Provider:: environment
#
# Copyright 2014, Virender Khatri
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# use_inline_resources

def whyrun_supported?
  true
end

action :create do
  new_resource.updated_by_last_action(true) if create_objects
end

action :delete do
  new_resource.updated_by_last_action(true) if create_objects
end

protected

def create_objects
  search_pattern = new_resource.search_pattern || "chef_environment:#{new_resource.environment}"
  if new_resource.limit_region && !new_resource.server_region
    if node.key?('ec2')
      server_region = node['ec2']['placement_availability_zone'].chop
    else
      # add more cloud providers
      server_region = nil
    end
  end
  env_resources = Icinga2::Search.new(:environment => new_resource.environment,
                                      :enable_cluster_hostgroup => new_resource.enable_cluster_hostgroup,
                                      :cluster_attribute => new_resource.cluster_attribute,
                                      :enable_application_hostgroup => new_resource.enable_application_hostgroup,
                                      :application_attribute => new_resource.application_attribute,
                                      :enable_role_hostgroup => new_resource.enable_role_hostgroup,
                                      :ignore_node_error => new_resource.ignore_node_error,
                                      :use_fqdn_resolv => new_resource.use_fqdn_resolv,
                                      :failover_fqdn_address => new_resource.failover_fqdn_address,
                                      :ignore_resolv_error => new_resource.ignore_resolv_error,
                                      :exclude_recipes => new_resource.exclude_recipes,
                                      :exclude_roles => new_resource.exclude_roles,
                                      :env_custom_vars => new_resource.env_custom_vars,
                                      :env_filter_node_vars => new_resource.env_filter_node_vars,
                                      :limit_region => new_resource.limit_region,
                                      :server_region => server_region,
                                      :search_pattern => search_pattern,
                                      :add_cloud_custom_vars => new_resource.add_cloud_custom_vars).environment_resources

  template_file_name = new_resource.zone ? "host_#{new_resource.environment}_#{new_resource.zone}.conf" : "host_#{new_resource.environment}.conf"
  hosts_template = template ::File.join(node['icinga2']['objects_dir'], template_file_name) do
    source "object.#{::File.basename(__FILE__, '.rb')}.conf.erb"
    cookbook 'icinga2'
    owner node['icinga2']['user']
    group node['icinga2']['group']
    mode 0640
    variables(:environment => new_resource.environment,
              :hosts => env_resources['nodes'],
              :import => new_resource.import,
              :check_command => new_resource.check_command,
              :max_check_attempts => new_resource.max_check_attempts,
              :check_period => new_resource.check_period,
              :check_interval => new_resource.check_interval,
              :retry_interval => new_resource.retry_interval,
              :enable_notifications => new_resource.enable_notifications,
              :enable_active_checks => new_resource.enable_active_checks,
              :enable_passive_checks => new_resource.enable_passive_checks,
              :enable_event_handler => new_resource.enable_event_handler,
              :enable_flapping => new_resource.enable_flapping,
              :enable_perfdata => new_resource.enable_perfdata,
              :event_command => new_resource.event_command,
              :flapping_threshold => new_resource.flapping_threshold,
              :volatile => new_resource.volatile,
              :zone => new_resource.zone,
              :command_endpoint => new_resource.command_endpoint,
              :notes => new_resource.notes,
              :notes_url => new_resource.notes_url,
              :action_url => new_resource.action_url,
              :icon_image => new_resource.icon_image,
              :icon_image_alt => new_resource.icon_image_alt)
    notifies :reload, 'service[icinga2]', :delayed
  end
  return true if hosts_template.updated? || create_hostgroups(env_resources)
end

def create_hostgroups(env_resources)
  env_hostgroups = []

  # environment hostgroups
  env_hostgroups += env_resources['clusters'] if new_resource.enable_cluster_hostgroup

  env_hostgroups += env_resources['applications'] if new_resource.enable_application_hostgroup

  env_hostgroups += env_resources['roles'] if new_resource.enable_role_hostgroup

  env_hostgroups.uniq!

  hostgroup_template = icinga2_envhostgroup new_resource.environment do
    groups env_hostgroups
  end

  hostgroup_template.updated?
end
