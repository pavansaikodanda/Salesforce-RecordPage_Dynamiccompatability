public class FormSaveController {

    @AuraEnabled
    public static FormWrappers.SaveResultWrapper saveRecord(
        String objectApiName,
        String recordId,
        String fieldDataJson
    ) {
        FormWrappers.SaveResultWrapper result = new FormWrappers.SaveResultWrapper();
        try {
            Map<String, Object> fieldData = (Map<String, Object>) JSON.deserializeUntyped(fieldDataJson);

            SObject record = Schema.getGlobalDescribe().get(objectApiName).newSObject();

            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get(objectApiName).getDescribe().fields.getMap();

            for (String fieldName : fieldData.keySet()) {
                Object val = fieldData.get(fieldName);
                if (val == null) continue;

                Schema.SObjectField sof = fieldMap.get(fieldName.toLowerCase());
                if (sof == null) continue;

                Schema.DisplayType fieldType = sof.getDescribe().getType();

                if (fieldType == Schema.DisplayType.INTEGER) {
                    record.put(fieldName, Integer.valueOf(String.valueOf(val)));
                } else if (fieldType == Schema.DisplayType.LONG) {
                    record.put(fieldName, Long.valueOf(String.valueOf(val)));
                } else if (
                    fieldType == Schema.DisplayType.CURRENCY ||
                    fieldType == Schema.DisplayType.DOUBLE ||
                    fieldType == Schema.DisplayType.PERCENT
                ) {
                    record.put(fieldName, Decimal.valueOf(String.valueOf(val)));
                } else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    record.put(fieldName, Boolean.valueOf(String.valueOf(val)));
                } else if (fieldType == Schema.DisplayType.DATE) {
                    record.put(fieldName, Date.valueOf(String.valueOf(val)));
                } else if (fieldType == Schema.DisplayType.DATETIME) {
                    record.put(fieldName, DateTime.valueOf(String.valueOf(val)));
                } else {
                    record.put(fieldName, String.valueOf(val));
                }
            }

            if (String.isBlank(recordId)) {
                insert record;
                result.recordId = record.Id;
            } else {
                record.put('Id', recordId);
                update record;
                result.recordId = recordId;
            }
            result.isSuccess = true;

        } catch (DmlException e) {
            result.isSuccess = false;
            result.errorMessage = e.getDmlMessage(0);
        }
        return result;
    }
}
