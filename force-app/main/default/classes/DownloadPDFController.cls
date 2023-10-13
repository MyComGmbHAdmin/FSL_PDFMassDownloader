global class DownloadPDFController {
    global List<ServiceAppointment> selectedAppointments { get; set; }
    global List<SelectOption> templateOptions { get; set; }
    global List<String> paramId { get; set; }
    global static List<ContentDocumentLink> documentLink { get; set; }

    static {
        documentLink = new List<ContentDocumentLink>();
    }

    global DownloadPDFController() {
        // Initialize Controller by capturing parameters from the URL
        Map<String, String> params = ApexPages.currentPage().getParameters();

        // Retrieve the "services" parameter as a comma-separated string
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

        selectedAppointments = new List<ServiceAppointment>();
        templateOptions = new List<SelectOption>();

        fetchServiceAppointments();
        loadTemplateOptions();
    }

    global void fetchServiceAppointments() {
        this.selectedAppointments = [SELECT Id, AppointmentNumber, Status, Street, City, EarliestStartTime, AnschreibenErstelltAm__c FROM ServiceAppointment WHERE Id IN :paramId];
    }

    // Method to load the available PDF templates into the select list
    global void loadTemplateOptions() {
        List<PDFTemplate__c> templates = getListOfPDFTemplates();
        for (PDFTemplate__c template : templates) {
            templateOptions.add(new SelectOption(template.Id, template.Name));
        }
    }

    public static List<PDFTemplate__c> getListOfPDFTemplates() {
        return [
            SELECT Id, Name, ObjectName__c, FileTitle__c
            FROM PDFTemplate__c
        ];
    }

    @RemoteAction
    global static String createTitle(String title, Id recordId) {
        String nameOfFile = '';
        nameOfFile = Utilities.replaceAdditionalVariables(title, recordId);
        nameOfFile = Utilities.replaceAllFieldReferences(nameOfFile, recordId);
        return nameOfFile;
    }

    @RemoteAction
    global static String createPDFUsingTemplate(String title, Id templateId, Id recordId) {
        Blob pdfPage = getPDF(templateId, recordId);
        // Create an item of content, then get the link to that
        // then save as a file with the parent object
        ContentVersion file = new ContentVersion();
        file.ContentLocation = 'S';

        // Make substitutions for the filename as required
        String nameOfFile = '';
        nameOfFile = Utilities.replaceAdditionalVariables(createTitle(title, recordId), recordId);
        nameOfFile = Utilities.replaceAllFieldReferences(nameOfFile, recordId);

        file.pathOnClient = nameOfFile + '.pdf';
        file.title = nameOfFile;
        file.versionData = pdfPage;
        Database.SaveResult saveResult;
        try {
            saveResult = Database.insert(file);
        }
        catch (DmlException e) {
            System.debug('Failed to insert file, error is ' + e.getMessage());
        }

        Id contentDocumentId = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id =:file.Id
        ].ContentDocumentId;

        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocumentId;
        link.LinkedEntityId = recordId;
        link.ShareType = 'I'; // Inferred permission
        documentLink.add(link);
        System.debug('documentLink '+documentLink);
        //insert link;

        return EncodingUtil.base64Encode(pdfPage);
    }

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

    @RemoteAction
    global static String addLinkAndTimestamp(String selectedAppointmentIds) {
        List<Id> appointmentIds = (List<Id>) JSON.deserialize(selectedAppointmentIds, List<Id>.class);
        List<ServiceAppointment> serviceAppointmentsToBeUpdated = new List<ServiceAppointment>();
        
        for(ServiceAppointment appointment : [SELECT Id, AnschreibenErstelltAm__c FROM ServiceAppointment WHERE Id IN :appointmentIds]) {
            appointment.AnschreibenErstelltAm__c = System.now().addHours(2);
            serviceAppointmentsToBeUpdated.add(appointment);
        }
        
        try {
            upsert serviceAppointmentsToBeUpdated;
            upsert documentLink;
            return 'Success';
        } catch (Exception e) {
            return e.getMessage();
        }
    }
}