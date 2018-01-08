require 'trello'

class MappingsController < ApplicationController
  unloadable

  before_filter :find_project_by_project_id, :authorize
  before_filter :setup_trello_api

  def index
    @board_lists = []
    if @project.trello_board_id.present?
      # "//close" => Our special magic option to close (archive) the card
      @extra_close_option = [l(:trello_card_sync_close_option), '//close']
      @board_lists = Trello::Board.find(@project.trello_board_id).lists.map { |list| [list.name, list.id] }
      @board_lists << @extra_close_option
    else
      flash[:warning] = t(:trello_card_sync_no_board_specified_warning, project: @project.name)
    end
    @excluded_trackers = excluded_trackers
    @excluded_trackers_v2 = excluded_trackers_v2
    @list_mapping = list_mapping
  end

  def save
    begin
      @project.trello_board_id = params[:project][:trello_board_id]
      @project.trello_excluded_trackers = params[:project][:trello_excluded_trackers].to_s
      @project.trello_excluded_trackers_v2 = params[:project][:trello_excluded_trackers].to_json
      @project.trello_list_mapping = params[:trello_list_mapping].to_json
      @project.save!
      redirect_to mappings_url, notice: l(:trello_card_sync_settings_saved)
    rescue StandardError => e
      redirect_to mappings_url, alert: e.to_s
    end
  end

  private

  def excluded_trackers
    JSON.parse(@project.trello_excluded_trackers).reject(&:empty?).map(&:to_i)
  end

  def excluded_trackers_v2
    if @project.trello_excluded_trackers.present? && !@project.trello_excluded_trackers_v2.present?
      @project.trello_excluded_trackers_v2 = JSON.parse(@project.trello_excluded_trackers).to_json
      @project.save!
    end
    JSON.load(@project.trello_excluded_trackers_v2).reject(&:empty?).map(&:to_i)
  end

  def list_mapping
    list_mapping = {}
    if @project.trello_list_mapping.present?
      list_mapping = Hash[JSON.load(@project.trello_list_mapping).map { |k, v| [k.to_i, v.to_s] }]
    end
    list_mapping
  end

  def setup_trello_api
    Trello.configure do |config|
      config.developer_public_key = Setting.plugin_redmine_trello_card_sync['public_key'].present? ? Setting.plugin_redmine_trello_card_sync['public_key'].strip : ''
      config.member_token = Setting.plugin_redmine_trello_card_sync['member_token'].present? ? Setting.plugin_redmine_trello_card_sync['member_token'].strip : ''
    end
  end
end
