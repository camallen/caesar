class WorkflowsController < ApplicationController
  responders :flash

  def index
    @workflows = policy_scope(Workflow).all.sort_by(&:id)
    @workflow = Workflow.new
    respond_with @workflows
  end

  def show
    authorize workflow
    @summary = WorkflowSummary.new(workflow)
    respond_with @workflow
  end

  def new
    skip_authorization

    unless params[:id].present?
      head :bad_request
      return
    end

    if workflow = Workflow.accessible_by(credential).find_by(id: params[:id])
      redirect_to workflow
      return
    end

    workflow_hash = credential.accessible_workflow?(params[:id])

    if workflow_hash.present?
      @workflow = Workflow.new(id: params[:id], project_id: workflow_hash["links"]["project"])
    else
      head :not_found
    end
  end

  def create
    skip_authorization
    workflow_id = params[:workflow][:id]

    workflow_hash = credential.accessible_workflow?(params[:workflow][:id])

    unless workflow_hash.present?
      skip_authorization
      head :forbidden
      return
    end

    @workflow = Workflow.new(workflow_params.merge(
      id: workflow_id,
      project_id: workflow_hash["project_id"] || -1,
      name: workflow_hash["display_name"] || "New Workflow"
    ))

    @workflow.save

    DescribeWorkflowWorker.perform_async(@workflow.id) unless @workflow.id.blank?

    respond_to do |format|
      format.html { respond_with @workflow, location: workflows_path }
      format.json { render json: workflow }
    end
  end

  def update
    authorize workflow

    if params[:workflow][:rerun] == 'extractors'
      rerun_extractors
      respond_with workflow, location: workflow_path(@workflow, anchor: 'extractors')
    elsif params[:workflow][:rerun] == 'reducers'
      rerun_reducers
      respond_with workflow, location: workflow_path(@workflow, anchor: 'reducers')
    else
      was_paused = workflow.paused?
      workflow.update(workflow_params)

      if was_paused && workflow.active?
        UnpauseWorkflowWorker.perform_async workflow.id
        flash[:notice] = 'Resuming workflow'
      end

      if !was_paused && workflow.paused?
        flash[:notice] = 'Pausing workflow'
      end

      if was_paused && workflow.active?
        UnpauseWorkflowWorker.perform_async workflow.id
      end

      Workflow::ConvertLegacyExtractorsConfig.new(workflow).update(params[:workflow][:extractors_config])
      Workflow::ConvertLegacyReducersConfig.new(workflow).update(params[:workflow][:reducers_config])
      Workflow::ConvertLegacyRulesConfig.new(workflow).update(params[:workflow][:rules_config])
      respond_with workflow
    end
  end

  private

  def workflow
    @workflow ||= policy_scope(Workflow).find(params[:id])
  end

  def rerun_extractors
    duration = 3.hours

    workflow.extracts.pluck(:subject_id).uniq.each do |subject_id|
      FetchClassificationsWorker.perform_in(rand(duration.to_i).seconds, workflow.id, subject_id, FetchClassificationsWorker.fetch_for_subject)
    end

    flash[:notice] = "Re-running extractors for the next #{duration / 1.hour.to_i} hours"
  end

  def rerun_reducers
    duration = 3.hours

    workflow.extracts.group_by(&:subject_id).each do |subject_id, extracts|
      ReduceWorker.perform_in(rand(duration.to_i).seconds, workflow.id, 'Workflow', subject_id, nil, extracts.pluck(:id))
    end

    flash[:notice] = "Re-running reducers for the next #{duration / 1.hour.to_i} hours"
  end

  def workflow_params
    params.require(:workflow).permit(
      :public_extracts,
      :public_reductions,
      :status,
      :rules_applied,
      :rerun,
    )
  end
end
