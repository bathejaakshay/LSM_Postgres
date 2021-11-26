from django import forms

class FormName(forms.Form):
    sentence = forms.CharField(max_length=50)
    target_sentence = forms.CharField(max_length=50)
    # output1 = forms.CharField(required = False)
    # output2 = forms.CharField(required = False)
    