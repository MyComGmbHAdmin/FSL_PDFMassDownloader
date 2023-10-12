/**
 * Author: MyCom, Jon Jardine
 * Created: 2023 02 28
 * Description: Helpful methods and functions
 */

 public with sharing class Utilities {
    
    private static final String FIELD_PATTERN = '\\{!(.*?)\\}';
    private static final String FIELD_WITH_ATTRIBUTES_PATTERN = '\\{!(\\w{1,})(.*?)\\}';

    private static final String TAG_PATTERN = '\\{@(\\w{1,})(.*?)\\}(.*?)\\{\\/@\\1\\}';
    private static final String ATTRIBUTE_PATTERN = '\\s?(\\w+)=\\"(.*?)\\"\\s?';
    private static final String FIELD_TAG = '{!FIELD}';
    private static final String FIELD_ATTRIBUTES_TAG = '{!FIELD ATTRIBUTES}';

    public static final String PRIORITY = 'priority';
    public static final String PRIORITY_HIGH = 'high';
    public static final String PRIORITY_MEDIUM = 'medium';
    public static final String PRIORITY_LOW = 'low';
    public static final String PRIORITY_NONE = '';

    public static final String ERROR_TAG_UNKNOWN = '<span style="color:red;"><b>{??@TAG_NAME}</b></span>';


    /**
     * Provide a list of additional variable classes that provide more content
     */
    public static final List<String> ADDITIONAL_VARIABLES = new List<String>{ 
        'USER_VARIABLES', 
        'DATE_VARIABLES',
        'OWNER_VARIABLES'
    };

    /**
     * Remove all linebreaks / carriage returns from the text
     */
    public static String removeLineBreaks(String content) {
        return content.replaceAll('\r\n|\n|\r', '');
    }

    /**
     * Determine if the module is running under a namespace
     * to allow for accessing static resources in a managed package context
     */
    public static String getNamespace() {
        String className = Utilities.class.getName();
        String namespace = className.contains('.')
            ? className.split('\\.')[0] 
            : '';
        
        return namespace;
    }

    /**
     * Provide a namespaced version of the fieldname -
     * for when running as a managed package -
     * primarily for test classes
     */
    public static String getNamespacedField(String field) {
        String namespace = getNamespace();
        if (namespace.length() > 0) {
            return namespace + '__' + field;
        }
        return field;
    }

    public static String replaceAdditionalVariables(String content, Id recordId) {
        String replaced = content;

        // Query each Variable class in turn and ask if it needs any fields fetched
        // from the record for it to do its stuff...

        List<String> fieldList = new List<String>();
        for (String var: ADDITIONAL_VARIABLES) {
            Type v = Type.forName(var);
            try {
                Variables vars = (Variables) v.newInstance();
                List<String> fieldsForVariablesClass = vars.fieldsNeeded();
                if (fieldsForVariablesClass != null) {
                    for (String fieldName: fieldsForVariablesClass) {
                        if (!fieldList.contains(fieldName)) {
                            fieldList.add(fieldName);
                        }
                    }
                }
            }
            catch (Exception e) {
                // Unknown VARIABLES class
                System.debug(e);
            }
        }

       // Utilities.checkIfFieldExistsInRecord('OwnerId', record)

        SObject record;
        if (fieldList.size() > 0) {
            record = getRecordData(fieldList, recordId);
        }

        for (String var: ADDITIONAL_VARIABLES) {
            Type v = Type.forName(var);
            try {
                Variables vars = (Variables) v.newInstance();
                Map<String, String> varList = vars.provide(record);
                for (String key: varList.keySet()) {
                    String value = varList.get(key);
                    if (value != null) {
                        replaced = replaced.replace('{!' + key + '}', value);
                    }
                }
            } catch (Exception e) {
                // Unknown VARIABLES class
                System.debug(e);
            }
        }
        // All information replaced in content
        return replaced;
    }


    /**
     * Find all the fields referenced in the content, 
     * uses regular expression pattern matching to find occurrences
     * of {!field_name__c} type tags
     */
    public static List<String> findAllFields(String content) {
        List<String> fieldList = new List<String>();
        Pattern fieldPattern = Pattern.compile(FIELD_PATTERN);
        Matcher m = fieldPattern.matcher(content);
        while (m.find()) {
            // Get the field name (group(0) returns then entire match)
            fieldList.add(m.group(1));
        }
        return fieldList;
    }
    

    /**
     * Find all the fields referenced in the content which have attributes, 
     * uses regular expression pattern matching to find occurrences
     * of {!field_name__c foo="value" bar="value"} type tags
     * Note that the matching will return fields without any attributes
     * so these aren't included in the list returned
     */
    public static  Map<String, List<Map<String, String>>> findAllFieldsWithAttributes(String content) {
        Map<String, List<Map<String, String>>> fieldPlusAttributesList = new Map<String, List<Map<String, String>>>();
        Pattern fieldPattern = Pattern.compile(FIELD_WITH_ATTRIBUTES_PATTERN);
        Matcher m = fieldPattern.matcher(content);
        while (m.find()) {
            // Get the field name (group(0) returns then entire match)
            String fieldName = m.group(1);
            // Get the attributes
            String attributesString = m.group(2);
            Map<String, String> attributes = new Map<String, String>();
            List<Map<String, String>> attributesList = new List<Map<String, String>>();

            if (attributesString != null && attributesString.length() > 0) {
                attributes = processAttributes(attributesString);
                if (fieldPlusAttributesList.get(fieldName) != null) {
                    attributesList = fieldPlusAttributesList.get(fieldName);
                }
                attributesList.add(attributes);
                fieldPlusAttributesList.put(fieldName, attributesList);
            } 
        }
        return fieldPlusAttributesList;
    }


    /**
     * Get the object record with the Id recordId,
     * fetching the list of fields provided
     */
    public static SObject getRecordData(List<String> fieldList, Id recordId) {
        String objectName = recordId.getSObjectType().getDescribe().getName();
        List<String> fields = new List<String>();
        for (String field: fieldList) {
            if (!fields.contains(field)) {
                fields.add(field);
            }
        }
        // Sanity check to ensure that at least one field is fetched
        if (fields.size() == 0) {
            fields.add('Id');
        }
        String query = 'SELECT ' +
                        String.join(fields, ',') +
                        ' FROM ' + objectName +
                        ' WHERE Id=\'' + recordId + 
                        '\' LIMIT 1';

        System.debug(query);
        return Database.query(query);
    }

    /**
     * Get records from an object, filtered
     * by the supplied where clause
     * fetching the list of fields provided
     */
    public static List<SObject> getRecords(List<String> fieldList, String objectName, String whereClause, Integer resultLimit, String orderByStatement) {
        List<String> fields = new List<String>();
        String recordLimit = '';
        if (resultLimit > 0) {
            recordLimit = ' LIMIT ' + resultLimit;
        }
        String whereString = (whereClause != null && whereClause.length() > 0) 
            ? ' WHERE ' + whereClause
            : '';

        String orderByStatementString = '';
        if (orderByStatement != null) {
            orderByStatementString = orderByStatement;
        }

        for (String field: fieldList) {
            if (!fields.contains(field)) {
                fields.add(field);
            }
        }
        // Sanity check to ensure that at least one field is fetched
        if (fields.size() == 0) {
            fields.add('Id');
        }
        String query = 'SELECT ' +
                        String.join(fields, ',') +
                        ' FROM ' + objectName +
                        whereString + 
                        orderByStatementString +
                        recordLimit;

        System.debug(query);

        return Database.query(query);
    }

    public static String replaceAllFieldWithAttributesReferences(String content, Id recordId) {
        String replaced = '';
        Map<String, List<Map<String, String>>> fieldsPlusAttributes = findAllFieldsWithAttributes(content);
        System.debug('REPLACE ALL FIELDS WITH ATTRIBUTES:');
        System.debug(fieldsPlusAttributes);
        if (!fieldsPlusAttributes.isEmpty()) {
            List<String> fieldList = new List<String>(fieldsPlusAttributes.keySet());
            List<String> validFieldList = getValidFields(fieldList, recordId);
            List<String> invalidFieldList = getInvalidFields(fieldList, recordId);
            SObject record = getRecordData(validFieldList, recordId);
            if (record == null) {
                return replaced;
            }
            replaced = replaceFieldPlusAttributeTagsWithData(content, record, validFieldList, fieldsPlusAttributes);
            replaced = replaceUnknownFieldPlusAttributeTagsWithErrors(replaced, invalidFieldList);
        }

        else {
            replaced = content;
        }
        return replaced;
    }

    /**
     * Find and replace all the field references 
     * (of the form {!field_name__c} or {!Object__c.field_name__c})
     * in the content. All the field references are validated first to ensure
     * that no unknown fields can break the SOQL query.
     * Any unknown fields are highlighted in the output.
     */
    public static String replaceAllFieldReferences(String content, Id recordId) {
        String replaced = '';
        List<String> fieldList = findAllFields(content);
        if (fieldList.size() > 0) {
            // Ensure that the field list is valid
            List<String> validFieldList = getValidFields(fieldList, recordId);
            List<String> invalidFieldList = getInvalidFields(fieldList, recordId);
            SObject record = getRecordData(validFieldList, recordId);
            if (record == null) {
                return replaced;
            }
            replaced = replaceFieldTagsWithData(content, record, validFieldList);
            replaced = replaceUnknownFieldTagsWithErrors(replaced, invalidFieldList);
        } 
        else {
            replaced = content;
        }
        return replaced;
    }

    /**
     * Determine whether or not a fieldname exists in the record object,
     * and if not return false
     */
    public static Boolean checkIfFieldExistsInRecord(String field, SObject record) {
        if (record == null) {
            return false; 
        }
        System.debug('Checking if field type exists in record');
        System.debug(field);
        System.debug(record.getSObjectType());
        String fieldType = getFieldType(field, record.getSObjectType());
        return (fieldType != null && fieldType.length() > 0);
    }

    /**
     * Provide a list of the field names that exist in the object or any related object
     */
    public static List<String> getValidFields(List<String> fieldList, Id recordId) {
        List<String> validFields = new List<String>{};
        SObjectType objectType = recordId.getSObjectType();
        for (String field: fieldList) {
            String fieldType = getFieldType(field, objectType);
            if (fieldType != null && fieldType.length() > 0) {
                validFields.add(field);
            }
        }
        return validFields;
    }

    /**
     * Provide a list of the field names that do not exist in the object
     */
    public static List<String> getInvalidFields(List<String> fieldList, Id recordId) {
        List<String> invalidFields = new List<String>{};
        SObjectType objectType = recordId.getSObjectType();
        for (String field: fieldList) {
            String fieldType = getFieldType(field, objectType);
            if (fieldType == null || (fieldType != null && fieldType.length() == 0)) {
                invalidFields.add(field);
            }
        }
        return invalidFields;
    }  

    /**
     * Get the value of the specified field from the current record
     * Note that relationship lookups are supported, and can be 
     * more than one level deep
     */
    public static String getFieldValueFromRecord(String field, SObject record) {
        String value;
        if (record == null) {
            return value;
        }
        // Relationship lookup
        // Supports relationships deeper than one level
        if (field.contains('.')) {
            value = walkThroughRecordRelationships(record, field);
        }
        // Simple field from this record
        else {
            SObjectType recordType = getSObjectType(record.getSObjectType().getDescribe().getName()); 
            Object lookupValue = record.get(field);
            String fieldType = getFieldType(field, recordType);
            // Format the value without any custom attributes
            value = formatValue(lookupValue, fieldType, null);
        }
        return value;
    }

    public static Object getUnformattedFieldValueFromRecord(String field, SObject record) {
        Object value;
        if (record == null) {
            return value;
        }
        if (field.contains('.')) {
            value = walkThroughRecordRelationships(record, field);
        }
        // Simple field from this record
        else {
            SObjectType recordType = getSObjectType(record.getSObjectType().getDescribe().getName()); 
            value = record.get(field);
        }
        return value;
    }


        /**
     * Get the value of the specified field from the current record
     * Note that relationship lookups are supported, and can be 
     * more than one level deep
     */
    public static String getFieldValueFromRecordWithCustomAttributes(String field, SObject record, Map<String, String> attributes) {
        String value;
        if (record == null) {
            return value;
        }
        // Relationship lookup
        // Supports relationships deeper than one level
        if (field.contains('.')) {
            value = walkThroughRecordRelationships(record, field);
        }
        // Simple field from this record
        else {
            SObjectType recordType = getSObjectType(record.getSObjectType().getDescribe().getName()); 
            Object lookupValue = record.get(field);
            String fieldType = getFieldType(field, recordType);
            value = formatValue(lookupValue, fieldType, attributes);
        }
        return value;
    }


    /**
     * Substitute all the fields in the content with their values
     */
    public static String replaceFieldTagsWithData(String content, SObject record, List<String> fields) {
        String updatedContent = content;
        if (record == null) {
            return updatedContent;
        }
        for (String field: fields) {
            String value = getFieldValueFromRecord(field, record);
            // Now replace the value in the content
            String tag = FIELD_TAG.replace('FIELD', field);
            updatedContent = (value != null) 
                ? updatedContent.replace(tag, value)
                : updatedContent.replace(tag, '');
        }
        return updatedContent;
    }

    public static String replaceUnknownFieldTagsWithErrors(String content, List<String> fields) {
        String updatedContent = content;
        for (String field: fields) {
            String value = '<span style="color: red; font-weight: bold;">{??' + field + '}</span>';
            // Now replace the value in the content
            String tag = FIELD_TAG.replace('FIELD', field);
            updatedContent = (value != null) 
                ? updatedContent.replace(tag, value)
                : updatedContent.replace(tag, '');
        }
        return updatedContent;
    }

    /**
     * Substitute all the fields in the content based their values and attributes
     */
    public static String replaceFieldPlusAttributeTagsWithData(String content, SObject record, List<String> fields, Map<String, List<Map<String, String>>> fieldsPlusAttributes) {
        String updatedContent = content;
        if (record == null) {
            return updatedContent;
        }
        for (String field: fields) {
            List<Map<String, String>> attributesList = fieldsPlusAttributes.get(field);
            System.debug(attributesList);
            for (Map<String, String> attributes: attributesList) {
                String value = getFieldValueFromRecordWithCustomAttributes(field, record, attributes);
                String attributesString = '';
            
                for (String key: attributes.keySet()) {
                    String val = attributes.get(key);
                    if (attributesString.length() > 0) {
                        attributesString += ' ';
                    }
                    attributesString += key + '="' + val + '"';
                }
                // Now replace the value in the content
                String tag = FIELD_ATTRIBUTES_TAG.replace('FIELD', field);
                System.debug(attributesString);
                tag = tag.replace('ATTRIBUTES', attributesString);
                System.debug('Replacing tag ' + tag);
                updatedContent = (value != null) 
                    ? updatedContent.replace(tag, value)
                    : updatedContent.replace(tag, '');
            }
        }
        return updatedContent;
    }

    public static String replaceUnknownFieldPlusAttributeTagsWithErrors(String content, List<String> fields) {
        String updatedContent = content;
        for (String field: fields) {
            String value = '<span style="color: red; font-weight: bold;">{??' + field + '}</span>';
            // Now replace the value in the content
            String tag = FIELD_TAG.replace('FIELD', field);
            updatedContent = (value != null) 
                ? updatedContent.replace(tag, value)
                : updatedContent.replace(tag, '');
        }
        return updatedContent;
    }

    /**
     * Woo - the field is actually a relationship to another object, or potentially
     * a relationship of a relationship. Walk through these until the final
     * field value is found, and return it
     */
    public static String walkThroughRecordRelationships(SObject record, String field) {
        if (record == null) {
            return '';
        }
        if (field == null || field.length() == 0) {
            return '';
        }
        if (!field.contains('.')) {
            // Check to ensure that there is a relationship; if not, just return the value    
            SObjectType recordType = getSObjectType(record.getSObjectType().getDescribe().getName()); 
            Object lookupValue = record.get(field);
            String fieldType = getFieldType(field, recordType);
            return formatValue(lookupValue, fieldType, null);
        }

        // A relationship is found - walk through it
        List<String> relationship = field.split('\\.');
        Integer lookupCount = relationship.size() - 1;
        Integer index = 0;
        SObjectType sObjectType;
        SObject related = record;
        String recordObjectName = record.getSObjectType().getDescribe().getName();
        String parentName;
        String relatedName;
        Object lookupValue;
        Boolean found = true;
        while (lookupCount > 0 && found) {
            lookupCount--;
            parentName = relationship[index];
            relatedName = relationship[index + 1];
            relatedName = relatedName.replace('__r', '__c');
            if (recordObjectName != parentName && lookupExists(parentName, related)) {
                related = related.getSObject(parentName);
                lookupValue = related.get(relatedName);
                sObjectType = getSObjectType(related.getSObjectType().getDescribe().getName());
            }
            // else if (recordObjectName != parentName && fieldExists(record, recordObjectName)) {
            //     // Lookup is stored as an Id in ths parent
            //     System.debug('+++ Lookup - ' + recordObjectName);
            //     String childId = getFieldValueFromRecord(recordObjectName, record);
            //     System.debug('+++ Child Id is ' + childId);
            //     // Now get the type of the child
            //     relatedName = getSObjectNameFromId(childId);
            //     System.debug('+++ Child type is ' + relatedName);
            // }
            else if (recordObjectName == parentName) {
                // The main object name has been included - ignore this...
                // and go through the relationship again (if it now becomes a simple field lookup,
                // the first check in this method accounts for this)
                List<String> revisedRelationship = new List<String>();
                for (Integer i = relationship.size() - 1; i > 0 ; i--) {
                    revisedRelationship.add(relationship.get(i));
                }
                String newRelationships = String.join(revisedRelationship, '.');
                return walkThroughRecordRelationships(record, newRelationships);
            }
            else {
                // Relationship not found
                found = false;
            }
            index++;
        } 
        String value = (found) ? formatValue(lookupValue, getFieldType(relatedName, sObjectType), null) : '';
        return value;
    }
    
    /**
     * Format values (currency, date, datetime)
     * This method relies on formatters, which are based on the 'Format' class
     * The datatype is used to instantiate the relevant formatter,
     * unless (future expansion, the attributes specify a 'type' in which
     * case the default is overrriden)
     */
    public static String formatValue(Object value, String dataType, Map<String, String> attributes) {
        String formatted;
        
        // Create an instance of the relevant format class,
        // e.g. 'CURRENCY_FORMAT'
        // and call the formatter method to get the formatted value
        Type f = Type.forName(dataType + '_FORMAT');
        try {
            Format formatter = (Format) f.newInstance();
            System.debug('Formatter initialised');
            formatted = formatter.formatter(attributes, value);
        } catch (Exception e) {
            // For any other type or if the formatter doesn't exist,
            // just return as the String value
            System.debug(e);
            System.debug('Formatter "' + dataType + '_FORMAT" does not exist.');
            formatted = String.valueOf(value);
        }
        return formatted;
    }

    /**
     * Get the name of the SObject from the passed Id
     */
    public static String getSObjectNameFromId(Id objectId) {
        return objectId.getSobjectType().getDescribe().getName();
    }

    /**
     * Instantiate an SObject of the passed string
     * to ascertain its type
     */
    public static SObjectType getSObjectType(String objectName) {
        return ((SObject)(Type.forName('Schema.' + objectName).newInstance())).getSObjectType();
    }

    /**
     * Check to see if the specified field exists as a lookup
     * in the current object
     */
    public static Boolean lookupExists(String fieldAPINameR, SObject vObject) {
        String fieldAPINameC = fieldAPINameR.replace('__r', '__c');
        if (!fieldAPINameC.contains('__c')) {
            fieldAPINameC = fieldAPINameC + 'Id'; // Try to use an Id lookup
        }
        Boolean exists = false;
        try {
            exists = vObject.get(fieldAPINameC) != null && String.valueOf(vObject.get(fieldAPINameC)) != '';
        } catch (Exception e) {
            System.debug('Exception - Object ' + vObject.getSObjectType() + 'doesn\'t contain field ' + fieldAPINameC + '!');
        }
        
        return exists;
    }

    /**
     * Get the field description for the field
     */
    public static Schema.DescribeFieldResult getFieldDescription(String field, SObjectType sObjectType) {
        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        Schema.DescribeFieldResult fieldResult;
        if (field.contains('.')) {
            String lookup = field.split('\\.')[0];
            if (lookup.contains(('__r'))) {
                lookup = lookup.replace('__r', '__c');
            }
            else {
                lookup += 'Id';

            }
            if (fieldMap.get(lookup) != null) {
                List<Schema.SObjectType> lookupList = fieldMap.get(lookup).getDescribe().getReferenceTo();
                if (lookupList.size() > 0) {
                    String lookupObject = String.valueOf(lookupList[0].getDescribe().getName());
                    SObjectType lookupSObjectType = getSObjectType(lookupObject);
                    Map<String, Schema.SObjectField> lookupFieldMap = lookupSObjectType.getDescribe().fields.getMap();
                    String lookupFieldName = field.split('\\.')[1];
                    if (lookupFieldMap.get(lookupFieldName) != null) {
                        fieldResult = lookupFieldMap.get(lookupFieldName).getDescribe();
                    }
                    else {
                        System.debug('Field "' + field + '" not found in related object schema! Here are those that are available...');
                        for (String name: lookupFieldMap.keySet()) {
                            System.debug(name + ' => ' + lookupFieldMap.get(name));
                        }
                    }
                } 
            }  
        }
        else {
            if (fieldMap.get(field) != null) {
                fieldResult = fieldMap.get(field).getDescribe();
            }
        }
        return fieldResult;
    }


    /**
     * Get the specified field's type as a string
     */
    public static String getFieldType(String field, SObjectType sObjectType) {
        Schema.DescribeFieldResult fieldResult = getFieldDescription(field, sObjectType);
        if (fieldResult != null) {
            String fieldType = String.valueOf(fieldResult.getType());
            System.debug(field + ' => ' + fieldType);
            return fieldType;
        }
        return null;
    }


    /**
     * Process any tags or fields that exist and return the processed content
     */
    public static String processTagsAndFieldsIfTheyExist(String content, Id recordId) {
        String newContent = content;
        if (newContent.contains('{@')) {
            newContent = processAllTags(newContent, recordId);
        }
        if (newContent.contains('{!')) {
            newContent = replaceAllFieldWithAttributesReferences(newContent, recordId);
            newContent = replaceAllFieldReferences(newContent, recordId);
        }    
        return newContent;    
    }

    public static String processAllTags(String content, Id recordId) {

        // Get all the fields referenced in the tags 
        // and fetch the record with those fields
        // (this is potentially a repeat but it keeps the code MUCH simpler)
        List<String> fieldList = getListOfFieldsReferencedInTags(content);
        List<String> validFieldList = Utilities.getValidFields(fieldList, recordId);

        SObject record;
        if (validFieldList.size() > 0) {
            record = getRecordData(validFieldList, recordId);
        }
        else {
            List<String> idOnlyList = new List<String>{'Id'};
            record = getRecordData(idOnlyList, recordId);
        }

        // Process the high, medium and low priority tags
        // Use a string contains check to see if the attributes
        // are present in the template. Note that there might be
        // unwanted collisions here in the unlikely event that
        // the template contains "high" or similar as a bit of text!
        // However the overhead for processing should be pretty low
        // in case of false positives.
        if (content.contains('"' + PRIORITY_HIGH + '"')) {
            content = getTagsWithPriority(content, record, PRIORITY_HIGH);
        }
        if (content.contains('"' + PRIORITY_MEDIUM + '"')) {
            content = getTagsWithPriority(content, record, PRIORITY_MEDIUM);
        }
        if (content.contains('"' + PRIORITY_LOW + '"')) {
            content = getTagsWithPriority(content, record, PRIORITY_LOW);
        }

        // Now process any tags without a priority
        content = getTagsWithPriority(content, record, PRIORITY_NONE);

        return content;
    }

    public static String getTagsWithPriority(String content, SObject record, String priority) {
        String updatedContent = '';
        Integer offset = 0;

        Pattern tagPattern = Pattern.compile(TAG_PATTERN);
        Matcher m = tagPattern.matcher(content);
        while (m.find()) {
            Integer blockStart = m.start();
            Integer blockEnd = m.end();
            String tagName = m.group(1);
            String attributeString = m.group(2);
            Map<String, String> attributes = new Map<String, String>();
            if (attributeString != null && attributeString.length() > 0) {
                attributes = processAttributes(attributeString);
            }
            Boolean priorityMatches = false;
            if ((attributes.get(PRIORITY) != null && attributes.get(PRIORITY) == priority) || priority == PRIORITY_NONE) {
                priorityMatches = true;
            }
            if (priorityMatches) {
                String innerContent = m.group(3);

                updatedContent += content.substring(offset, blockStart); //  - 1

                Type t = Type.forName(tagName);
                try {
                    Tag tag = (Tag) t.newInstance();
                    String newContent = tag.process(attributes, record, innerContent);
                    updatedContent += newContent;
                    
                } catch (Exception e) {
                    System.debug(e);
                    updatedContent += ERROR_TAG_UNKNOWN.replace('TAG_NAME', tagName);
                }
                
                offset = blockEnd; // + 1
            }

        }
        if (updatedContent != '') {
            updatedContent += content.substring(offset, content.length());
        }
        // Return either changed content or the original 
        // if no tags were found at the relevant priority
        return (updatedContent != '') ? updatedContent : content; 
    }

    /**
     * Find a list of all the tags in the content, then scan these tags for field names
     */
    public static List<String> getListOfFieldsReferencedInTags(String content) {
        List<String> fieldList = new List<String>();
        Pattern tagPattern = Pattern.compile(TAG_PATTERN);
        Matcher m = tagPattern.matcher(content);
        while (m.find()) {
            String tagName = m.group(1);
            Map<String, String> attributes = processAttributes(m.group(2));
            String innerContent = m.group(3);
            Type t = Type.forName(tagName);
            try {
                Tag tag = (Tag) t.newInstance();
                fieldList.addAll(tag.scan(attributes, innerContent));
            } catch (Exception e) {
                System.debug('Tag class ' + tagName + ' not found.');
            }
        }
        return fieldList;
    }

    /**
     * Convert an attribute string of the form 
     * related="Appointment__c" idField="Invoice__c" priority="high"
     * into a map of key / value pairs for processing by the tags
     */
    public static Map<String, String> processAttributes(String attributeString) {
        Map<String, String> attributes = new Map<String, String>();
        if (attributeString != null && attributeString.length() > 0) {
            Pattern attrPattern = Pattern.compile(ATTRIBUTE_PATTERN);
            Matcher m = attrPattern.matcher(attributeString);
            while (m.find()) {
                String name = m.group(1);
                String value = m.group(2);
                attributes.put(name, value);
            }
        }
        return attributes;
    }

    /**
     * Determine the week number of the year
     * Taken from https://developer.salesforce.com/forums/?id=906F00000008ueCIAQ
     */
    public static Integer isoWeekNumber(Date value) {
		Integer daysSince1900_01_07 = Date.newInstance(1900, 1, 7).daysBetween(value);
		Integer dayNumber = Math.mod(daysSince1900_01_07, 7) + 1;
		
		Date dateForYear = value.addDays(Math.mod(8 - dayNumber, 7) - 3);
		Integer year = dateForYear.year();
		Date year_01_01 = Date.newInstance(year, 1, 1);
		
		Integer week = (Integer)Math.floor((year_01_01.daysBetween(value)
				+ Math.mod((Math.mod(Date.newInstance(1900, 1, 7).daysBetween(year_01_01), 7) + 1) + 1, 7) - 3) / 7 + 1);
				
		return week;
	}

    /**
     * Returns the day of the week of the supplied date. Note that casting
     * to date time uses the user's locale so timezone adjustments could
     * return an incorrect day, hence creating a new instance with midnight 
     * as the time to avoid timezone gotchas!
     */
    public static Integer dayOfWeek(Date value) {
        DateTime dt = DateTime.newInstance(value, Time.newInstance(0,0,0,0));
        String dayOfWeek = dt.format('u');
        return Integer.valueOf(dayOfWeek);
    }

    /**
     * Convert the string to kebab case, e.g.
     * Max Mustermann becomes 'max-mustermann'
     */
    public static String toKebabCase(String input) {
        Pattern p = Pattern.compile('\\ ?\\-?[a-zA-Z]');
        Matcher m = p.matcher(input);
        String kebabed = '';

        while (m.find()) {
            String c = m.group(0);
            if (c == ' ' || c == '-') {
                kebabed += '-';
            } else if (c.substring(0, 1) == ' ') {
                kebabed += '-' + c.substring(1).toLowerCase();
            } else {
                kebabed += c.toLowerCase();
            }
        }
        kebabed = kebabed.replaceAll('--', '-');
        return kebabed;
    }

    public static void sendPDFViaEmail(Blob content, String title, String subject, String emailBody, String ccEmails, String toEmails) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toEmails.split(','));
        mail.setHtmlBody(emailBody);
        mail.setSubject(subject);

        if (ccEmails != null && ccEmails != '') {
            mail.setCcAddresses(ccEmails.split(','));
        }

        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName(title + '.pdf');
        efa.setBody(content);
        attachments.add(efa);

        mail.setFileAttachments(attachments);

        // Send the email you have created.
        if(Test.isRunningTest() == false) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }

    public static void sendPDFViaEmailTemplate(Blob content, String title, String ccEmails, String toEmails, String objectId, String whatId, String emailTemplateName, Boolean setActivity) {
        Map<String,EmailTemplate> emailTemplateMap = loadTemplates();
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (ccEmails != null && ccEmails != '') {
            mail.setCcAddresses(ccEmails.split(','));
        }

        if (toEmails != null && toEmails != '') {
            mail.setToAddresses(toEmails.split(','));
        }

        mail.setTemplateId(emailTemplateMap.get(emailTemplateName).Id);
        mail.setTargetObjectId(objectId);
        mail.setWhatId(whatId);
        mail.setSaveAsActivity(setActivity);

        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName(title + '.pdf');
        efa.setBody(content);
        attachments.add(efa);

        mail.setFileAttachments(attachments);

        // Send the email you have created.
        if(Test.isRunningTest() == false) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }

    public static void saveFileToRecord(Blob content, Id recordId, String nameOfFile) {
        ContentVersion file = new ContentVersion();
        file.ContentLocation = 'S';
        file.pathOnClient = nameOfFile + '.pdf';
        file.title = nameOfFile;
        file.versionData = content;
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
        link.ShareType = 'I';

        insert link;
    }

    private static Map<String,EmailTemplate> loadTemplates() {
        Map<String,EmailTemplate> emailTemplateMap = new Map<String,EmailTemplate>();

        for(EmailTemplate emailTemplate : [SELECT Id, Name FROM EmailTemplate]) {
            emailTemplateMap.put(
                emailTemplate.Name,
                emailTemplate
            );
        }

        return emailTemplateMap;
    }

    /**
     * Load an HTML template saved to a zip file in static resources
     */
    public static String loadHTMLTemplateFromStaticResources(String folder, String filename) {
        PageReference fileRef = PageReference.forResource(getNamespace() + '__' + filename, folder);
        String template = fileRef.getContent().toString();
        return template;
    }
}