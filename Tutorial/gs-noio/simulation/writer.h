#ifndef __WRITER_H__
#define __WRITER_H__

// #IO# include IO library
#include <mpi.h>

#include "gray-scott.h"
#include "settings.h"

class Writer
{
public:
    Writer(const Settings &settings, const GrayScott &sim);
    void open(const std::string &fname);
    void write(int step, const GrayScott &sim);
    void close();

    void print_settings();

protected:
    const Settings &settings;
};

#endif
