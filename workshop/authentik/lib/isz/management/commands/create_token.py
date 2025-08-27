from authentik.core.models import User
from authentik.crypto.models import CertificateKeyPair
from authentik.providers.oauth2.models import (
  AccessToken,
  OAuth2Provider,
  ScopeMapping,
)
from authentik.providers.oauth2.id_token import IDToken
from django.http import HttpRequest
from django.utils.timezone import now
from django.core.management.base import BaseCommand
import os

class Command(BaseCommand):
  help = "Create an access token for a user"

  def add_arguments(self, parser):
    parser.add_argument('provider_name')
    parser.add_argument('user_name')

  def handle(self, provider_name, user_name, **options):
    request = HttpRequest()
    request.META = {
      'SERVER_PORT': '443',
      'HTTP_X_FORWARDED_PROTO': 'https',
      'SERVER_NAME': CertificateKeyPair.objects.get(
        managed__startswith='goauthentik.io/crypto/discovered/'
      ).name,
    }
    provider = OAuth2Provider.objects.get(name=provider_name)
    user = User.objects.get(name=user_name)
    access_token = AccessToken(
      provider=provider,
      user=user,
      expiring=False,
      auth_time=now(),
      scope=set(
        ScopeMapping.objects.filter(
          provider__in=[provider],
        ).values_list("scope_name", flat=True)
      ),
    )
    access_token.id_token = IDToken.new(provider, access_token, request)
    access_token.save()
    print(f"New token for {user} on {provider}:")
    print(access_token.token)
