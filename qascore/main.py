from sentence_transformers import SentenceTransformer
from indicnlp.normalize.indic_normalize import IndicNormalizerFactory

# model_labse = SentenceTransformer('sentence-transformers/LaBSE')
# model_pml = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')
def normalization(embeds):
  norms = np.linalg.norm(embeds, 2, axis=1, keepdims=True)
  return embeds/norms

def get_score(sentence1,sentence2):
  remove_nuktas=False
  factory=IndicNormalizerFactory()
  normalizer=factory.get_normalizer("hi",remove_nuktas=False)
  output_text1=[normalizer.normalize(sentence1)]
  output_text2=[normalizer.normalize(sentence2)]
  print(output_text1)
  print(output_text2)
  hi_em_pml = model_pml.encode(output_text1)
  em_mr_pml = model_pml.encode(output_text2)
  hindi_embeds_pml = normalization(hi_em_pml)
  marathi_embeds_pml = normalization(em_mr_pml)
  hi_em_labse = model_labse.encode(output_text1)
  em_mr_labse = model_labse.encode(output_text2)
  hindi_embeds_labse = normalization(hi_em_labse)
  marathi_embeds_labse = normalization(em_mr_labse)
  # print (np.matmul(english_embeds, np.transpose(italian_embeds)))
  similarity_pml = np.matmul(hindi_embeds_pml, np.transpose(marathi_embeds_pml))
  # sim_pml = np.diag(similarity_pml)
  similarity_labse = np.matmul(hindi_embeds_labse, np.transpose(marathi_embeds_labse))
  # sim_pml = np.diag(similarity_pml)
  print(similarity_labse,'\n',similarity_pml)
  return similarity_labse,similarity_pml