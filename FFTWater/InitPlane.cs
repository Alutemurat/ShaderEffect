using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InitPlane : MonoBehaviour
{
    public int rowCount = 10, columnCount = 10;

    GameObject plane;
    Mesh _mesh;
    Vector3 position;

    List<Vector3> vertices=new List<Vector3>();
    List<Vector3> normals=new List<Vector3>();
    List<int> quads = new List<int>();
    List<Vector2> uvs = new List<Vector2>();

    // Start is called before the first frame update
    void Start()
    {
        plane = gameObject;
        _mesh=plane.GetComponent<MeshFilter>().mesh;
        position = plane.transform.position;
        Generate();
    }


    void Generate()
    {
        Check();
        InitVertices();
        AddQuads();
        Apply();
    }

    void InitVertices()
    {
        vertices.Clear();
        normals.Clear();
        uvs.Clear();

        float perLength = (float)1f / (rowCount - 1);
        float perWidth = (float)1f / (columnCount - 1);
        float u = (float)1f / (rowCount-1);
        float v = (float)1f / (columnCount-1);

        Vector3 vertex = Vector3.zero;
        Vector3 normal = new Vector3(0, 1, 0);
        Vector2 uv = Vector2.zero;

        for (int row = 0; row < rowCount; row++)
        {
            for (int column = 0; column < columnCount; column++)
            {
                //vertex = position;
                vertex.x = row * perLength;
                vertex.z = column * perWidth;
                uv.y = 1-row * u;
                uv.x = column * v;

                vertices.Add(vertex);
                normals.Add(normal);
                uvs.Add(uv);
            }
        }
    }

    void Check()
    {
        if(rowCount<2)
        {
            rowCount = 2;
        }
        if (columnCount < 2)
        {
            columnCount = 2;
        }
    }

    void AddQuads()
    {
        quads.Clear();
        for (int row = 0; row < rowCount-1; row++)
        {
            for (int column = 0; column < columnCount-1; column++)
            {
                quads.Add(column + row * columnCount);
                quads.Add((column + 1) + row * columnCount);
                quads.Add((column + 1) + (row + 1) * columnCount);

                quads.Add(column + row * columnCount);
                quads.Add((column + 1) + (row + 1) * columnCount);
                quads.Add(column + (row + 1) * columnCount);
            }
        }
    }

    void Apply()
    {
        _mesh.vertices = vertices.ToArray();
        _mesh.triangles = quads.ToArray();
        _mesh.normals = normals.ToArray();
        _mesh.uv = uvs.ToArray();
    }
}
