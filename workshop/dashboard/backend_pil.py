#!/usr/bin/env python3

from PIL import Image, ImageDraw
from more_itertools import flatten, split_before

from matplotlib import _api
from matplotlib._pylab_helpers import Gcf
from matplotlib.backend_bases import (
     FigureCanvasBase, FigureManagerBase, GraphicsContextBase, RendererBase)
from matplotlib.figure import Figure
from matplotlib.path import Path
from matplotlib.transforms import Affine2D

FLIPY = Affine2D.identity().scale(1, -1)

class RendererPIL(RendererBase):
    def __init__(self, im, dpi):
        super().__init__()
        self.im = im
        self.draw = ImageDraw.Draw(self.im)
        self.dpi = dpi

    def draw_path(self, gc, path, transform, rgbFace=None):
        #transform += FLIPY
        bbox = gc.get_clip_rectangle() if gc else None
        maxcoord = 16383 / 72.27 * self.dpi  # Max dimensions in LaTeX.
        if bbox and (rgbFace is None):
            p1, p2 = bbox.get_points()
            clip = (max(p1[0], -maxcoord), max(p1[1], -maxcoord),
                    min(p2[0], maxcoord), min(p2[1], maxcoord))
        else:
            clip = (-maxcoord, -maxcoord, maxcoord, maxcoord)
        for poly in split_before(
                path.iter_segments(transform, snap=True, simplify=True, curves=False, clip=clip),
                lambda pc: pc[1] == Path.MOVETO,
        ):
            points = [(points[0], self.im.height-points[1]) for points,_ in poly]
            self.draw.line(points, fill=0)

    # draw_markers is optional, and we get more correct relative
    # timings by leaving it out.  backend implementers concerned with
    # performance will probably want to implement it
#     def draw_markers(self, gc, marker_path, marker_trans, path, trans,
#                      rgbFace=None):
#         pass

    # draw_path_collection is optional, and we get more correct
    # relative timings by leaving it out. backend implementers concerned with
    # performance will probably want to implement it
#     def draw_path_collection(self, gc, master_transform, paths,
#                              all_transforms, offsets, offsetTrans,
#                              facecolors, edgecolors, linewidths, linestyles,
#                              antialiaseds):
#         pass

    # draw_quad_mesh is optional, and we get more correct
    # relative timings by leaving it out.  backend implementers concerned with
    # performance will probably want to implement it
#     def draw_quad_mesh(self, gc, master_transform, meshWidth, meshHeight,
#                        coordinates, offsets, offsetTrans, facecolors,
#                        antialiased, edgecolors):
#         pass

    def draw_image(self, gc, x, y, im):
        pass

    def draw_text(self, gc, x, y, s, prop, angle, ismath=False, mtext=None):
        """
        Draw the text instance.
        Parameters
        ----------
        gc : `.GraphicsContextBase`
            The graphics context.
        x : float
            The x location of the text in display coords.
        y : float
            The y location of the text baseline in display coords.
        s : str
            The text string.
        prop : `matplotlib.font_manager.FontProperties`
            The font properties.
        angle : float
            The rotation angle in degrees anti-clockwise.
        mtext : `matplotlib.text.Text`
            The original text object to be rendered.
        """
        mask = self.draw.getfont().getmask(s, self.draw.fontmode)
        angle = round(angle/90)
        if angle != 0:
            mask = mask.transpose(1+angle)
        bbox = mask.getbbox()
        width = bbox[2]-bbox[0]
        height = bbox[3]-bbox[1]
        y -= height
        if angle in (1,3):
            x -= width
        self.draw.draw.draw_bitmap((x,y), mask, 0)

    def flipy(self):
        # docstring inherited
        return True

    def get_canvas_width_height(self):
        # docstring inherited
        return self.im.width, self.im.height

    def get_text_width_height_descent(self, s, prop, ismath):
        width, height = self.draw.textsize(s)
        return width, height, 0.2*height
        #bbox = self.draw.textbbox((0,0), s)
        #return bbox[2]-bbox[0], bbox[3]-bbox[2], 0.2*(bbox[2]-bbox[0])

    def new_gc(self):
        # docstring inherited
        return GraphicsContextPIL()

    def points_to_pixels(self, points):
        # if backend doesn't have dpi, e.g., postscript or svg
        #return points
        # elif backend assumes a value for pixels_per_inch
        # return points/72.0 * self.dpi.get() * pixels_per_inch/72.0
        # else
        return points/72.0 * self.dpi


class GraphicsContextPIL(GraphicsContextBase):
    """
    The graphics context provides the color, line styles, etc...  See the cairo
    and postscript backends for examples of mapping the graphics context
    attributes (cap styles, join styles, line widths, colors) to a particular
    backend.  In cairo this is done by wrapping a cairo.Context object and
    forwarding the appropriate calls to it using a dictionary mapping styles
    to gdk constants.  In Postscript, all the work is done by the renderer,
    mapping line styles to postscript calls.
    If it's more appropriate to do the mapping at the renderer level (as in
    the postscript backend), you don't need to override any of the GC methods.
    If it's more appropriate to wrap an instance (as in the cairo backend) and
    do the mapping here, you'll need to override several of the setter
    methods.
    The base GraphicsContext stores colors as a RGB tuple on the unit
    interval, e.g., (0.5, 0.0, 1.0). You may need to map this to colors
    appropriate for your backend.
    """


########################################################################
#
# The following functions and classes are for pyplot and implement
# window/figure managers, etc...
#
########################################################################


def new_figure_manager(num, *args, FigureClass=Figure, **kwargs):
    """Create a new figure manager instance."""
    # If a main-level app must be created, this (and
    # new_figure_manager_given_figure) is the usual place to do it -- see
    # backend_wx, backend_wxagg and backend_tkagg for examples.  Not all GUIs
    # require explicit instantiation of a main-level app (e.g., backend_gtk3)
    # for pylab.
    thisFig = FigureClass(*args, **kwargs)
    return new_figure_manager_given_figure(num, thisFig)


def new_figure_manager_given_figure(num, figure):
    """Create a new figure manager instance for the given figure."""
    canvas = FigureCanvasPIL(figure)
    manager = FigureManagerPIL(canvas, num)
    return manager


class FigureCanvasPIL(FigureCanvasBase):
    """
    The canvas the figure renders into.  Calls the draw and print fig
    methods, creates the renderers, etc.
    Note: GUI PILs will want to connect events for button presses,
    mouse movements and key presses to functions that call the base
    class methods button_press_event, button_release_event,
    motion_notify_event, key_press_event, and key_release_event.  See the
    implementations of the interactive backends for examples.
    Attributes
    ----------
    figure : `matplotlib.figure.Figure`
        A high-level Figure instance
    """

    def draw(self):
        """
        Draw the figure using the renderer.
        It is important that this method actually walk the artist tree
        even if not output is produced because this will trigger
        deferred work (like computing limits auto-limits and tick
        values) that users may want access to before saving to disk.
        """
        self.figure.draw_without_rendering()
        return super().draw()

    # You should provide a print_xxx function for every file format
    # you can write.

    # If the file type is not in the base set of filetypes,
    # you should add it to the class-scope filetypes dictionary as follows:
    filetypes = {**FigureCanvasBase.filetypes, 'pbm': 'Portable Bit Map'}

    @_api.delete_parameter("3.5", "args")
    def print_pbm(self, filename, *args, **kwargs):
        """
        Write out format foo.
        This method is normally called via `.Figure.savefig` and
        `.FigureCanvasBase.print_figure`, which take care of setting the figure
        facecolor, edgecolor, and dpi to the desired output values, and will
        restore them to the original values.  Therefore, `print_foo` does not
        need to handle these settings.
        """
        width, height = self.figure.get_size_inches()
        dpi = self.figure.dpi
        width = int(width * dpi)
        height = int(height * dpi)

        im = Image.new('1', (width, height), color=1)
        renderer = RendererPIL(im, self.figure.dpi)
        self.figure.draw(renderer)
        im.save(filename, format='ppm')

    def get_default_filetype(self):
        return 'pbm'


class FigureManagerPIL(FigureManagerBase):
    """
    Helper class for pyplot mode, wraps everything up into a neat bundle.
    For non-interactive backends, the base class is sufficient.
    """


########################################################################
#
# Now just provide the standard names that backend.__init__ is expecting
#
########################################################################

FigureCanvas = FigureCanvasPIL
FigureManager = FigureManagerPIL
