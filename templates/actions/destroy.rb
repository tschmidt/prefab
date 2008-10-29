  def destroy
    @<%= singular_name %> = <%= class_name %>.find(params[:id])
  
    if @<%= singular_name %>.destroy
      flash[:notice] = 'Successfully destroyed <%= name.humanize.downcase %>'
    else
      flash[:error] = '<%= name.humanize %> was not destroyed. Please try again.'
    end

    redirect_to <%= plural_name %>_url
  end