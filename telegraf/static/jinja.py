import ionit_plugin
import jinja2
from markupsafe import Markup

@ionit_plugin.function
def topython(i):
    return repr(i)

@ionit_plugin.function
@jinja2.pass_environment
def include_raw(env: jinja2.Environment, name: str):
    return Markup(env.loader.get_source(env, name)[0])
