#include "shMem.h"
#include <time.h>
#include <stdlib.h>

using namespace std;

//HOST
unsigned i = 0;
int freeShMem( struct Arrays *data ) /* free used shared memory for use with other clients */
{
    data->isBeingWritten = 0;
    if ( shmdt( data ) < 0 )
    {
        cerr << "child shmdt ERROR!\n";
        return -1;
    }
    return 0;
}

int destroyShMem( int &shmid )  /* destroy used shared memory (important!!!) */
{
    if ( shmctl( shmid, IPC_RMID, NULL ) < 0 )
    {
        cerr << "shmctl ERROR!\n";
        return -1;
    }
    return 0;
}

int isShMemWritable( struct Arrays *someData )
{
    if ( someData->isBeingWritten == 1 )
	{
		cout << "shared memory struct is busy!\n" << endl; 
		while ( someData->isBeingWritten == 1 ) 
		{
			if ( system( "sleep 0.001" ) )			 
			{
				cerr << "sleep error!\n"; 
				return -1; 
			}
		}
		cout << "shared memory container obtained\n";
	}
	return 0;
}

//===================================================
//GPU
//===================================================
__device__ 		unsigned 	d_arr1Size[ 1 ];
__device__ 		float 		d_arr1[ array1Size ];
__device__ 		unsigned 	d_arr2Size [ 1 ];
__device__ 		float 		d_arr2[ array2Size ];
void freeGPU()
{  
	cudaFree(				d_arr1Size 			);
    cudaFree( 				d_arr1 				);
	cudaFree(				d_arr2Size			);
    cudaFree( 				d_arr2 				);
    cudaDeviceSynchronize();
    cudaDeviceReset();
}

__global__ void printArr2()
{
	printf( "\n===========================\neach array access:\n" );
	for( unsigned i = 0; i < d_arr1Size[ 0 ]; i++ )
		printf( "d_arr1[%i]: %.2f\n", i, d_arr1[ i ] );
	printf( "\n" );
	for( unsigned i = 0; i < d_arr2Size[ 0 ]; i++ )
		printf( "d_arr2[%i]: %.2f\n", i, d_arr2[ i ] );
	printf( "===========================\n" );
}
__global__ void sync(){};

int main( void )
{
    int shmid = shmget( key, sizeof( Arrays ), 0666 ); if ( shmid < 0 ) 
		{ cerr << "shmget ERROR!\n"; return -1; }
    struct Arrays* someData = ( struct Arrays* )  shmat( shmid, NULL, 0 );
	if ( isShMemWritable( someData ) != 0 ) return -1;
	someData->isBeingWritten = 1;

	clock_t t = clock();
	if ( cudaMemcpyToSymbolAsync( d_arr1Size, &array1Size, sizeof( unsigned ) ) != cudaSuccess ) 
		{ cerr << "array1Size GPU copy error!\n"; freeGPU(); return -1; }
    if ( cudaMemcpyToSymbolAsync( d_arr1, &someData->array1[ 0 ], sizeof( float ) * array1Size ) != cudaSuccess ) 
		{ cerr << "array1 GPU copy error!\n"; freeGPU(); return -1; }
	if ( cudaMemcpyToSymbolAsync( d_arr2Size, &array2Size, sizeof( unsigned ) ) != cudaSuccess ) 
		{ cerr << "array2Size GPU copy error!\n"; freeGPU(); return -1; }
    if ( cudaMemcpyToSymbolAsync( d_arr2, &someData->array2[ 0 ], sizeof( float ) * array2Size ) != cudaSuccess ) 
		{ cerr << "array2 GPU copy error!\n"; freeGPU(); return -1; }
 	sync<<< 1, 1 >>> ();
	t = clock() - t; cout << "GPU H2D copy: " << t << " [CPU clocks]/" << CLOCKS_PER_SEC << " = " << float( t ) / CLOCKS_PER_SEC << "[ us ]" << endl;
    printArr2<<< 1, 1 >>>();

    if ( freeShMem( someData ) != 0 )  
		{ cerr << "Shared Memory free error!\n"; freeGPU(); return -1; }
	if ( destroyShMem( shmid ) != 0 )  
		{ cerr << "Shared Memory destroy error!\n"; freeGPU(); return -1; }
	freeGPU();
    return 0;
}

