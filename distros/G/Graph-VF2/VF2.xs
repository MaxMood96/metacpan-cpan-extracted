#include <boost/graph/adjacency_list.hpp>
#include <boost/graph/vf2_sub_graph_iso.hpp>

using namespace boost;

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

// Handle equivalence
template <typename PropertyMapFirst, typename PropertyMapSecond>
struct equivalence {
    equivalence(const PropertyMapFirst property_map1,
                const PropertyMapSecond property_map2):
        m_property_map1(property_map1),
        m_property_map2(property_map2) {}

    template <typename ItemFirst, typename ItemSecond>
    bool operator()(const ItemFirst item1, const ItemSecond item2) {
        return get(m_property_map2, item2)[get(m_property_map1, item1)];
    }

    private:
        const PropertyMapFirst m_property_map1;
        const PropertyMapSecond m_property_map2;
};

template <typename PropertyMapFirst, typename PropertyMapSecond>
equivalence<PropertyMapFirst, PropertyMapSecond>
    make_equivalence(const PropertyMapFirst property_map1,
                     const PropertyMapSecond property_map2) {

    return (equivalence<PropertyMapFirst, PropertyMapSecond>
            (property_map1, property_map2));
}

template <typename Graph1, typename Graph2>
struct correspondence_callback {
    correspondence_callback(const Graph1& graph1, const Graph2& graph2, std::vector<int>& correspondence)
      : graph1_(graph1), graph2_(graph2), correspondence_(correspondence) {}

    template <typename CorrespondenceMap1To2,
              typename CorrespondenceMap2To1>
    bool operator()(CorrespondenceMap1To2 f, CorrespondenceMap2To1) const {
        BGL_FORALL_VERTICES_T(v, graph1_, Graph1) {
            correspondence_.push_back( get(vertex_index_t(), graph1_, v) );
            correspondence_.push_back( get(vertex_index_t(), graph2_, get(f, v)) );
        }

        return true;
    }
    
    private:
        const Graph1& graph1_;
        const Graph2& graph2_;
        std::vector<int>& correspondence_;
};

MODULE = Graph::VF2		PACKAGE = Graph::VF2

SV *
_vf2(vertices1, edges1, vertices2, edges2, vertex_map, edge_map)
        SV * vertices1
        SV * edges1
        SV * vertices2
        SV * edges2
        SV * vertex_map
        SV * edge_map
    CODE:
        typedef property< vertex_name_t, ssize_t> query_vertex_property;
        typedef property< vertex_name_t, bool*> target_vertex_property;
        typedef property< edge_name_t, ssize_t> query_edge_property;
        typedef property< edge_name_t, bool*> target_edge_property;
        typedef adjacency_list< setS, vecS, undirectedS, query_vertex_property, query_edge_property > query_graph;
        typedef adjacency_list< setS, vecS, undirectedS, target_vertex_property, target_edge_property > target_graph;

        // Build graph1
        query_graph graph1;
        int num_vertices1 = av_top_index((AV*) SvRV(vertices1)) + 1;
        int num_edges1 = av_top_index((AV*) SvRV(edges1)) + 1;
        for (ssize_t i = 0; i < num_vertices1; i++)
            add_vertex( query_vertex_property(i), graph1 );
        for (ssize_t i = 0; i < num_edges1; i++) {
            AV * edge = (AV*) SvRV( av_fetch( (AV*) SvRV(edges1), i, 0 )[0] );
            add_edge( SvIV( av_fetch( edge, 0, 0 )[0] ),
                      SvIV( av_fetch( edge, 1, 0 )[0] ),
                      query_edge_property(i),
                      graph1 );
        }

        // Build graph2
        target_graph graph2;
        int num_vertices2 = av_top_index((AV*) SvRV(vertices2)) + 1;
        int num_edges2 = av_top_index((AV*) SvRV(edges2)) + 1;
        for (ssize_t i = 0; i < num_vertices2; i++) {
            AV * line = (AV*) SvRV( av_fetch( (AV*) SvRV(vertex_map), i, 0 )[0] );
            bool* vector = (bool*)calloc(num_vertices1, sizeof(bool));
            for (ssize_t j = 0; j < num_vertices1; j++) {
                vector[j] = SvIV( av_fetch( line, j, 0 )[0] );
            }
            add_vertex( target_vertex_property(vector), graph2 );
        }
        for (ssize_t i = 0; i < num_edges2; i++) {
            AV * edge = (AV*) SvRV( av_fetch( (AV*) SvRV(edges2), i, 0 )[0] );
            AV * line = (AV*) SvRV( av_fetch( (AV*) SvRV(edge_map), i, 0 )[0] );
            bool* vector = (bool*)calloc(num_edges1, sizeof(bool));
            for (ssize_t j = 0; j < num_edges1; j++)
                vector[j] = SvIV( av_fetch( line, j, 0 )[0] );
            add_edge( SvIV( av_fetch( edge, 0, 0 )[0] ),
                      SvIV( av_fetch( edge, 1, 0 )[0] ),
                      target_edge_property(vector),
                      graph2 );
        }

        auto vertex_comp = make_equivalence(get(vertex_name, graph1), get(vertex_name, graph2));
        auto edge_comp = make_equivalence(get(edge_name, graph1), get(edge_name, graph2));

        std::vector<int> correspondence;

        // Create callback to print mappings
        correspondence_callback< query_graph, target_graph > callback(graph1, graph2, correspondence);

        // Get all subgraph isomorphism mappings between graph1 and graph2.
        // Edges are assumed to be always equivalent.
        vf2_subgraph_iso(graph1, graph2, callback,
                         get(vertex_index, graph1), get(vertex_index, graph2),
                         vertex_order_by_mult(graph1),
                         edge_comp, vertex_comp);

        // Free the allocated memory
        auto vertex_property_map = get(vertex_name, graph2);
        auto edge_property_map = get(edge_name, graph2);
        BGL_FORALL_VERTICES_T(vertex, graph2, target_graph)
            free(vertex_property_map[vertex]);
        BGL_FORALL_EDGES_T(edge, graph2, target_graph)
            free(edge_property_map[edge]);

        AV* map = newAV();

        for (int n : correspondence)
            av_push( map, newSViv( n ) );

        RETVAL = newRV_noinc( (SV*)map );
    OUTPUT:
        RETVAL
