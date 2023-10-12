global class DownloadPDFController {
    global List<ServiceAppointment> selectedAppointments { get; set; }
    global List<SelectOption> templateOptions { get; set; }
    global List<String> paramId { get; set; }
    global String paramStart { get; set; }
    global String paramEnd { get; set; }

    global DownloadPDFController() {
        // Initialize your controller by capturing parameters from the URL
        Map<String, String> params = ApexPages.currentPage().getParameters();

        // Retrieve the "services"/"id" parameter as a comma-separated string
        String servicesParam;
        if(params.get('services') != null){
            servicesParam = params.get('services');
        } else {
            servicesParam = params.get('id');
        }

        if (!String.isBlank(servicesParam)) {
            // Split the comma-separated values and add them to the paramId list
            paramId = servicesParam.split(',');
        } else {
            paramId = new List<String>();
        }

        paramStart = params.get('start');
        paramEnd = params.get('end');

        selectedAppointments = new List<ServiceAppointment>();
        templateOptions = new List<SelectOption>();

        fetchServiceAppointments();
        loadTemplateOptions();

        System.debug('paramId' + paramId);
        System.debug('selectedAppointments' + selectedAppointments);
        System.debug('templateOptions' + templateOptions);

    }

    global void fetchServiceAppointments() {
        this.selectedAppointments = [SELECT Id, AppointmentNumber, Status, Street, City, EarliestStartTime FROM ServiceAppointment WHERE Id IN :paramId];
    }

    // Method to load the available PDF templates into the select list
    global void loadTemplateOptions() {
        List<PDFTemplate__c> templates = CreatePDF.getListOfPDFTemplates();
        for (PDFTemplate__c template : templates) {
            templateOptions.add(new SelectOption(template.Id, template.Name));
        }
    }

    @RemoteAction
    global static String createTitle(String title, Id recordId) {
        String nameOfFile = '';
        nameOfFile = Utilities.replaceAdditionalVariables(title, recordId);
        nameOfFile = Utilities.replaceAllFieldReferences(nameOfFile, recordId);
        return nameOfFile;
    }

    @RemoteAction
    global static String createPDFUsingTemplate(Id templateId, Id recordId) {
        Blob pdfPage = getPDF(templateId, recordId);
        return EncodingUtil.base64Encode(pdfPage);
    }

    // Get the PDF, however getContentAsPDF is not supported during tests,
    // so check if a test is running and return a dummy value
    @RemoteAction
    global static Blob getPDF(Id templateId, Id recordId) {
        PageReference pdfPage = Page.pdfwrapper;
        pdfPage.getParameters().put('templateId', templateId);
        pdfPage.getParameters().put('recordId', recordId);
        if (Test.isRunningTest()) {
            return Blob.valueOf('Unit Test');
        }
        else {
            return pdfPage.getContentAsPDF();
        }
        
    }
}