from django.shortcuts import render
from django.http import HttpResponse
from qascore.forms import FormName
from qascore.main import get_score
# Create your views here.
def index(request):
    form = FormName()
    context = {'form':form,'output': ' '}
    if request.method == 'POST':
        form = FormName(request.POST)
        if form.is_valid():
            print('sentence : ' + form.cleaned_data['sentence'])
            sentence1 = form.cleaned_data['sentence']
            sentence2= form.cleaned_data['target_sentence']
            output1,output2 = get_score(sentence1,sentence2)
        context = {'form':form,'labse': output1, 'pml': output2}
    return render(request,'qascore/index.html',context)