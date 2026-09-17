from django.urls import path
from . import views

urlpatterns = [
    path('', views.health_check),
    path('analyze-face', views.analyze_face),
]
