({
    handleClose: function () {
        var closeAction = $A.get('e.force:closeQuickAction');
        if (closeAction) {
            closeAction.fire();
        }
    }
})
