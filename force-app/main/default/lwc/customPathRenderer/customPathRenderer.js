import { LightningElement, api, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import STAGE_CHANGE_CHANNEL from '@salesforce/messageChannel/CustomFormStageChange__c';
import getFormConfig from '@salesforce/apex/FormConfigController.getFormConfig';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_TRANSITION_ERROR from '@salesforce/label/c.Path_Stage_Transition_Error';
import LABEL_LOADING from '@salesforce/label/c.Loading';
import LABEL_ERROR from '@salesforce/label/c.Error_Generic';

export default class CustomPathRenderer extends LightningElement {
    @api developerName;
    @api recordId;

    @wire(MessageContext) messageContext;

    @track pathConfig;
    @track currentStage;
    @track isLoading = true;
    @track errorMessage;

    connectedCallback() {
        this._load();
    }

    _load() {
        this.isLoading = true;
        getFormConfig({ developerName: this.developerName, recordId: this.recordId })
            .then(config => {
                this.pathConfig = config.pathConfig;
                this.currentStage = config.currentStageValue;
                this.isLoading = false;
            })
            .catch(err => {
                this.errorMessage = err.body?.message || LABEL_ERROR;
                this.isLoading = false;
            });
    }

    get stages() {
        if (!this.pathConfig?.stages) return [];
        return this.pathConfig.stages.map(s => ({
            ...s,
            displayLabel: s.stageLabel || s.stageValue,
            isCurrent: s.stageValue === this.currentStage,
            isCompleted: this._isCompleted(s.stageValue),
            cssClass: this._stageClass(s.stageValue)
        }));
    }

    get guidanceText() {
        if (!this.currentStage || !this.pathConfig?.stages) return '';
        const stage = this.pathConfig.stages.find(s => s.stageValue === this.currentStage);
        return stage?.guidanceText || '';
    }

    _isCompleted(stageValue) {
        if (!this.pathConfig?.stages || !this.currentStage) return false;
        const stages = this.pathConfig.stages;
        const currentIdx = stages.findIndex(s => s.stageValue === this.currentStage);
        const thisIdx = stages.findIndex(s => s.stageValue === stageValue);
        return thisIdx < currentIdx;
    }

    _stageClass(stageValue) {
        const base = 'slds-path__item';
        if (stageValue === this.currentStage) return base + ' slds-is-current slds-is-active';
        if (this._isCompleted(stageValue)) return base + ' slds-is-complete';
        return base + ' slds-is-incomplete';
    }

    handleStageClick(event) {
        const targetStage = event.currentTarget.dataset.stage;
        if (targetStage === this.currentStage) return;

        if (!this._isTransitionAllowed(this.currentStage, targetStage)) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Not Allowed',
                message: LABEL_TRANSITION_ERROR,
                variant: 'error'
            }));
            return;
        }

        this.currentStage = targetStage;
        publish(this.messageContext, STAGE_CHANGE_CHANNEL, {
            stageValue: targetStage,
            recordId: this.recordId
        });
        this.dispatchEvent(new CustomEvent('stagechange', {
            detail: { stageValue: targetStage },
            bubbles: true
        }));
    }

    _isTransitionAllowed(from, to) {
        if (!from) return true;

        const stages = this.pathConfig?.stages || [];
        const fromIdx = stages.findIndex(s => s.stageValue === from);
        const toIdx = stages.findIndex(s => s.stageValue === to);
        const isBackward = toIdx < fromIdx;

        const transitions = this.pathConfig?.transitions || [];

        // Backward moves always check the transitions list
        if (isBackward) {
            if (!transitions.length) return false;
            const match = transitions.find(t => t.fromStage === from && t.toStage === to);
            return match ? match.isAllowed : false;
        }

        // Forward moves: if enforceOrder is off, always allow
        if (!this.pathConfig?.enforceOrder) return true;

        // Forward moves with enforceOrder: check transitions list, else require sequential
        if (!transitions.length) {
            return toIdx === fromIdx + 1;
        }

        const match = transitions.find(t => t.fromStage === from && t.toStage === to);
        return match ? match.isAllowed : false;
    }
}
