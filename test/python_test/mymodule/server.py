#   Test server
#
import grpc
import math
import time
import threading
from concurrent import futures

import proto.route_guide_pb2_grpc as route_guide_pb2_grpc
import proto.route_guide_pb2 as route_guide_pb2

def get_feature(feature_db, point):
    """Returns Feature at given location or None."""
    for feature in feature_db:
        if feature.location == point:
            return feature
    return None

def get_distance(start, end):
    """Distance between two points."""
    coord_factor = 10000000.0
    lat_1 = start.latitude / coord_factor
    lat_2 = end.latitude / coord_factor
    lon_1 = start.longitude / coord_factor
    lon_2 = end.longitude / coord_factor
    lat_rad_1 = math.radians(lat_1)
    lat_rad_2 = math.radians(lat_2)
    delta_lat_rad = math.radians(lat_2 - lat_1)
    delta_lon_rad = math.radians(lon_2 - lon_1)

    # Formula is based on http://mathforum.org/library/drmath/view/51879.html
    a = (pow(math.sin(delta_lat_rad / 2), 2) +
         (math.cos(lat_rad_1) * math.cos(lat_rad_2) *
          pow(math.sin(delta_lon_rad / 2), 2)))
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    R = 6371000
    # metres
    return R * c

class RouteGuideServicer(route_guide_pb2_grpc.RouteGuideServicer):
    """Provides methods that implement functionality of route guide server."""

    def __init__(self, server, stop_event):
        self.server = server
        self.stop_event = stop_event

    def GetFeature(self, request, context):
        request.latitude = 89
        return route_guide_pb2.Feature(name="my_name", location=request)

    def ListFeatures(self, request, context):
        yield route_guide_pb2.Feature(name="12")
        yield route_guide_pb2.Feature(name="123932-04-034",
                                      location=route_guide_pb2.Point(latitude=400000000, longitude=-750000000))
        yield route_guide_pb2.Feature(name="1234",
                                      location=route_guide_pb2.Point(latitude=400000000, longitude=-750000000))

    def RecordRoute(self, request_iterator, context):
        point_count = 0
        feature_count = 0
        distance = 0.0
        prev_point = None

        start_time = time.time()
        for point in request_iterator:
            point_count += 1
            if get_feature(self.db, point):
                feature_count += 1
            if prev_point:
                distance += get_distance(prev_point, point)
            prev_point = point

        elapsed_time = time.time() - start_time
        return route_guide_pb2.RouteSummary(point_count=point_count,
                                            feature_count=feature_count,
                                            distance=int(distance),
                                            elapsed_time=int(elapsed_time))

    def RouteChat(self, request_iterator, context):
        prev_notes = []
        for new_note in request_iterator:
            for prev_note in prev_notes:
                if prev_note.location == new_note.location:
                    yield prev_note
            prev_notes.append(new_note)

    def TerminateServer(self, request, context):
        #self.server.stop(5)
        self.stop_event.set()
        return route_guide_pb2.Empty()

def serve(private_key, public_root_key):
    grpc_server = grpc.server(futures.ThreadPoolExecutor(max_workers=1))

    stop_event = threading.Event()
    servicer = RouteGuideServicer(grpc_server, stop_event)
    route_guide_pb2_grpc.add_RouteGuideServicer_to_server(servicer, grpc_server)
    grpc_server.add_insecure_port('[::]:40300')

    if private_key is not None and public_root_key is not None:
        server_certs_chain_pair = ((private_key, public_root_key),)

        ssl_credentials = grpc.ssl_server_credentials(server_certs_chain_pair)
        grpc_server.add_secure_port('[::]:40500', ssl_credentials)

    grpc_server.start()
    #grpc_server.wait_for_termination()
    stop_event.wait()
    grpc_server.stop(None)
    grpc_server.wait_for_termination()

    return None

if __name__ == '__main__':
    serve(None, None)
    print("Goodbye, World!")
