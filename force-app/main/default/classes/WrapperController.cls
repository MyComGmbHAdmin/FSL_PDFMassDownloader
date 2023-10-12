/**
 * Author: MyCom, Jon Jardine
 * Created: 2023 02 28
 * Description: the controller class for the 'pdfwrapper' VisualForce page
 * It takes an HTML template and the recordId (specified in the page GET variables)
 * and substitutes field values into the template, before rendering
 * the page as a PDF. Static resources (including CSS styles) are also
 * substituted, and optional tags can perform more advanced formatting and
 * substitution functions.
 */

 public with sharing class WrapperController {

    // The content for the page that will be substituted
    // onto the 'pdfwrapper' VisualForce page
    public String pageContent { get; set; }



    public WrapperController() {

        // Load the relevant HTML template
        // and return a failure message if not possible
        PDFTemplate__c pdf = loadTemplate();
        if (pdf == null) {
            pageContent = '<html><head></head><body>Unable to load HTML template to generate the PDF.</body></html>';
            return;
        }

        String template = pdf.HTMLContent__c;

        // Should content in an email template be substituted into the template?
        String emailTemplateSubstitution = null;
        Id emailTemplateId = ApexPages.currentPage().getParameters().get('emailTemplateId');
        if (emailTemplateId != null) {
            emailTemplateSubstitution = getEmailTemplateWithId(emailTemplateId);
            emailTemplateSubstitution = Utilities.removeLineBreaks(emailTemplateSubstitution);
            emailTemplateSubstitution = getBodyContent(emailTemplateSubstitution);
        }
       
        // Get the 'client' name
        String client = getClientInformation(template);

        // Substitute the {!RESOURCES} tags in the template
        // with the correct path to the staticresources/resources
        // directory with CSS and JPGs
        String content = replaceResourceTag(template);

        // Substitute the {!CLIENT_RESOURCES} tags in the template
        // with the correct path to the staticresources/client folder
        content = replaceClientResourceTag(content, client);

        // Substitude the {!STATIC} tags in the template
        // with the correct path to the staticresources folder
        content = replaceStaticResourceTag(content);

        // If an email template was specified for the content, substitute it into
        // the correct area in the PDF template 'wrapper'
        // and replace the {{{Object.Field}}} references.
        if (emailTemplateSubstitution != null && emailTemplateSubstitution.length() > 0) {
            content = content.replace('{!EMAIL_TEMPLATE_CONTENT}', emailTemplateSubstitution);
            content = content.replace('{{{', '{!');
            content = content.replace('}}}', '}');
        }

        // Remove the {!CLIENT} tag permutations...
        content = content.replace('{!CLIENT client="' + client + '"}', '');

        // Remove all the newlines from the content - this isn't required
        // for HTML output but the Regex pattern matcher doesn't
        // really support multiline regex so this is the easiest workaround...
        content = Utilities.removeLineBreaks(content);

        // Get the record ID of the currently viewed page
        Id recordId = ApexPages.currentPage().getParameters().get('recordId');     

        // Process all the {!User.Foo} variables
      //  content = Utilities.replaceCurrentUserVariables(content);

        // Process all the date variables
       // content = Utilities.replaceDateVariables(content);


        // Process all the additional variables
        content = Utilities.replaceAdditionalVariables(content, recordId);

        // Find all the processor tags (of the form {@TAG attributes}content{/@TAG})
        // and process them, substituting the results
        content = Utilities.processAllTags(content, recordId);

        // Find all the field + attribute tags {!field_name__c foo="bar"} specified in the content
        // and replace them with the data from the record
        // This includes formatting of values and defaults
        content = Utilities.replaceAllFieldWithAttributesReferences(content, recordId);

        // Find all the field tags {!field_name__c} specified in the content
        // and replace them with the data from the record
        content = Utilities.replaceAllFieldReferences(content, recordId);

        // Finally, put the processed content into the page
        pageContent = content;
    }


    /**
     * Get the Id of the template from the currently loaded Apex page
     * and load the specified template
     */
    @TestVisible private PDFTemplate__c loadTemplate() {
        Id templateId = ApexPages.currentPage().getParameters().get('templateId');
        if (templateId == null) {
            return null;
        }
        return getPDFTemplateWithId(templateId);
    }


    /**
     * Get the content between the <body> tags in an HTML string
     */

    public static String getBodyContent(String content) {

        Pattern tagPattern = Pattern.compile('<body.*?>(.*?)<\\/body>');
        Matcher m = tagPattern.matcher(content);
        String body = '';
        while (m.find()) {
            body = m.group(1);
        }
        return body;
    }

    
    /**
     * Get the name of the client stored in the template
     * of the form {!CLIENT client="mycom"}
     */
    public static String getClientInformation(String content) {
        Pattern tagPattern = Pattern.compile('\\{!CLIENT client="(.*?)"\\}');
        Matcher m = tagPattern.matcher(content);
        String clientName = '';
        while (m.find()) {
            clientName = m.group(1);
        }
        return clientName;
    }


    /**
     * Get the URL of the static resources location
     * and subtitute the {!STATIC} tag(s) in the template
     */
    public static String replaceStaticResourceTag(String content) {
        String resourcePath = '';
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        try {
            String resourceURL = PageReference.forResource('resources').getUrl();
            if (resourceURL.indexOf('?') >= 0) {
                resourcePath = resourceURL.subString(0, resourceURL.indexOf('?'));
            }
            resourcePath = resourcePath.substringBeforeLast('resources');
        } catch (Exception e) {
            System.debug(e);
        }
        String namespace = Utilities.getNamespace();
        if (namespace.length() > 0) {
            resourcePath = resourcePath.replace(namespace + '__', '');
        }
        resourcePath = baseURL + resourcePath;
        String replaced = content.replace('{!STATIC}', resourcePath);
        return replaced;
    }

    /**
     * Get the resource URL of the stylesheet and any images
     * and subtitute the {!RESOURCES} tag(s) in the template
     */
    public static String replaceResourceTag(String content) {
        String resourcePath = '';
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        try {
            String resourceURL = PageReference.forResource('resources').getUrl();
            if (resourceURL.indexOf('?') >= 0) {
                resourcePath = resourceURL.subString(0, resourceURL.indexOf('?'));
            }
        } catch (Exception e) {
            System.debug(e);
        }
        resourcePath = baseURL + resourcePath;
        String replaced = content.replace('{!RESOURCES}', resourcePath + '/');
        return replaced;
    }

    /**
     * Get the resource URL of the client resources and
     * substitute the {!CLIENT_RESOURCES} tag(s) in the template
     */
    public static String replaceClientResourceTag(String content, String client) {
        String resourcePath = '';
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();

        try {
            String resourceURL = PageReference.forResource(client).getUrl();
            if (resourceURL.indexOf('?') >= 0) {
                resourcePath = resourceURL.subString(0, resourceURL.indexOf('?'));
            }
        } catch (Exception e) {
            System.debug(e);
        }
        // String namespace = Utilities.getNamespace();
        // if (namespace.length() > 0) {
        //     resourcePath = resourcePath.replace(namespace + '__', '');
        // }
        resourcePath = baseURL + resourcePath;

        String replaced = content.replace('{!CLIENT_RESOURCES}', resourcePath + '/');
        return replaced;
    }


    /**
     * Get the template object specified by the Id
     */
    public static PDFTemplate__c getPDFTemplateWithId(Id templateId) { 
        List<PDFTemplate__c> templates = [
            SELECT Name, HTMLContent__c 
            FROM PDFTemplate__c 
            WHERE Id = :templateId LIMIT 1
        ];
        return (templates.size() == 1) ? templates[0] : null;
    }


    /**
     * Get the email template String specified by the Id
     */
    public static String getEmailTemplateWithId(Id emailTemplateId) { 
        List<EmailTemplate> templates = [
            SELECT Name, HtmlValue 
            FROM EmailTemplate 
            WHERE Id = :emailTemplateId LIMIT 1
        ];
        return (templates.size() == 1) ? templates[0].HtmlValue : null;
    }

}